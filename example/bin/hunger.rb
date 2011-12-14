#!/usr/bin/env ruby

require 'shellout'
require 'shellout/menu_query'
require 'shellout/task'
require 'shellout/query'

include Shellout

require 'readline'

# FIXME rename call to call everywhere? think call communicates the meaning more preciesly
Proc.send(:alias_method, :call, :call)

def text_effect(code, text); "\e[#{code}m#{text}\e[0m"; end

def bold(text); text_effect(1, text); end

def ask(question='')
  answer = Readline.readline(bold("#{question}> "), true)
  answer.strip
end

class DateQuery
   
   def call
     answer = ask("Date ([today] | ?)")
     if answer == '?'
       print_help
       return call
     end
     DateParser.parse(answer)
   end
   
   private

   def print_help
     puts "Accepted formats:"
     puts "        today | (+|-)n | [[[YY]YY]-[M]M]-[D]D"
     puts
     Calendar().print3
   end
   
end

# FIXME this is basically just a factory for constructing Date objects from a specially formated string.
class DateParser
  
  def self.parse(date_str, base=Date.today)
    raise ArgumentError.new('Invalid date') if date_str.nil? # FIXME return some sort of nil date object?
    
    # Today (default)
    if date_str == 'today' || date_str.empty?
      return Date.today
    end
    
    # Base offset
    case date_str.chars.first
    when '-'
      return base - Integer(date_str[1..-1])
    when '+'
      return base + Integer(date_str[1..-1])
    end
    
    # 
    date = date_str.split('-').collect {|d| d.to_i}
    case date.length
    when 1
      return Date.civil(base.year, base.month, *date)
    when 2
      return Date.civil(base.year, *date)
    when 3
      date[0] += 2000 if date[0] < 100
      return Date.civil(*date)
    end
    
    raise ArgumentError.new('Invalid date')
  end
  
end
 

class CommandLoop
  
  def initialize(menu)
    @menu = menu
  end
  
  def call
    loop do
      begin
        task = @menu.call
        task.call
      rescue Interrupt    # ^C
        puts              # Add a new line in case we are prompting
      end
    end
  end
  
end

class App

  def initialize
    @session = []
  end

  def define_course_task(dishes)
    Task.new do |t|
      t.dish     = MenuQuery.new(dishes)
      t.quantity = Query.new('How many?', 1)
      t.printf("%{quantity} %{dish} added to your order\n")
      t.on_call_done do
        @session << t
      end
    end
  end
  
  def main
  
    starters_task    = define_course_task(%w(Gazpacho Bruschetta))
    main_course_task = define_course_task(%w(Pizza Pasta))
    desserts_task    = define_course_task(%w(Gelato Tiramisu))
  
    checkout_task = Task.new do |t|
      t.date = DateQuery.new
      t.name = Query.new("Your name")
      t.on_call_done do
        confirmed = ask("Confirm (y|n)")
        @session = [] if confirmed == 'y'
      end
    end
    
    view_order_task = ->do
      #FIXME ugly
      rows = @session.map do |t|
        [t.instance_variable_get(:@results)[:quantity], t.instance_variable_get(:@results)[:dish]]
      end
      Table(headers: %w(quantity dish), rows: rows).print
      p @session
    end
    
    main_menu = Shellout::MenuQuery.new({
      "Starters"      => starters_task,
      "Main courses"  => main_course_task,
      "Desserts"      => desserts_task,
      "View Order"    => view_order_task,
      "Checkout"      => checkout_task,
      "Exit"          => ->{ exit }
    }, true)
    
    puts "Give up to your hunger!"
    CommandLoop.new(main_menu).call
  end
end

App.new.main