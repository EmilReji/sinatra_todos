require "sinatra"
require "sinatra/reloader" if development?
require "sinatra/content_for"
require "tilt/erubis"

configure do
  enable :sessions
  set :session_secret, 'secret'
end

before do
  session[:lists] ||= []
  update_todos_completed
end

helpers do
  def update_todos_completed
    session[:lists].each do |list|
      list[:todos_completed] = list[:todos].all?{ |todo| todo[:completed] == true }
      list[:todos_completed] = false if list[:todos].size == 0
    end
  end

  def remaining_todos(list)
    list[:todos].count { |todo| !todo[:completed] }
  end

  def list_class(list)
    "complete" if list[:todos_completed]
  end
  
  def sort_lists(lists, &block) 
    complete_lists, incomplete_lists = lists.partition { |list| list[:todos_completed] }
 
    incomplete_lists.each { |list| yield(list, lists.index(list)) }
    complete_lists.each { |list| yield(list, lists.index(list)) }
  end 
  
  def sort_todos(todos, &block)
    incomplete_todos = {}
    complete_todos = {}

    todos.each_with_index do |todo, index|
      if todo[:completed]
        complete_todos[todo] = index
      else
        incomplete_todos[todo] = index
      end
    end

    incomplete_todos.each(&block)
    complete_todos.each(&block)
  end 
end

get "/" do
  redirect "/lists"
end

# View list of lists
get "/lists" do
  @lists = session[:lists]
  erb :lists, layout: :layout
end

get "/lists/new" do
  erb :new_list, layout: :layout
end

def error_for_list_name(name)
  if !(1..100).cover?(name.size)
    "List name must be between 1 and 100 characters."
  elsif session[:lists].any? { |list| list[:name] == name }
    "List name must be unique."
  else
    nil
  end
end

def error_for_todo(name)
  if !(1..100).cover?(name.size)
    "Todo must be between 1 and 100 characters."
  end
end


# Create a new list
post "/lists" do
  list_name = params[:list_name].strip
  
  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :new_list, layout: :layout  
  else
    next_num = session[:lists].size
    session[:lists] << {num: next_num, name: list_name, todos: [], todos_completed: false}
    session[:success] = "The list has been created."
    redirect "/lists" 
  end
end

get "/lists/:num" do
  @list = session[:lists].find { |l| l[:num] == params[:num].to_i }
  @title = @list[:name]
  @items = @list[:todos]
  erb :list, layout: :layout
end

get "/lists/:num/edit" do
  @list = session[:lists].find { |l| l[:num] == params[:num].to_i }
  @title = @list[:name]
  erb :edit_list, layout: :layout
end

post "/lists/:num" do
  new_list_name = params[:list_name].strip 
  num = params[:num].to_i
  @list = session[:lists][num]
  old_list_name = @list[:name]
  @list[:name] = nil
  
  error = error_for_list_name(new_list_name)
  if error
    @list[:name] = old_list_name
    session[:error] = error
    erb :edit_list, layout: :layout
  else
    @list[:name] = new_list_name
    session[:success] = "The list name has been updated."
    redirect "/lists/#{params[:num]}"
  end 
end

# Delete a todo list
post "/lists/:num/delete" do
  num = params[:num].to_i
  session[:lists].delete_at(num)
  session[:lists].each_with_index do |list_hash, index|
    list_hash[:num] = index
  end
  session[:success] = "The list has been deleted." 
  redirect "/lists" 
end

# Add a new todo to a list
post "/lists/:num/todos" do
  num = params[:num].to_i
  @list = session[:lists].find { |l| l[:num] == params[:num].to_i }
  @title = @list[:name]
  @items = @list[:todos]

  text = params[:todo].strip
  
  error = error_for_todo(text) 
  if error
    session[:error] = error
    erb :list, layout: :layout
  else
    session[:lists][num][:todos] << {name: text, completed: false}
    session[:success] = "The todo was added."
    redirect "/lists/#{num}"
  end 
end

post "/lists/:num/:todo_num/delete" do
  num = params[:num].to_i
  todo_num = params[:todo_num].to_i
  session[:lists][num][:todos].delete_at(todo_num)
  session[:success] = "The todo item has been deleted."
  redirect "/lists/#{num}"
end

post "/lists/:num/:todo_num/toggle" do
  num = params[:num].to_i
  todo_num = params[:todo_num].to_i

  @list = session[:lists][num]
  @items = @list[:todos]
  item = @items[todo_num]
  
  is_completed = params[:completed] == "true"
  item[:completed] = is_completed
  
  session[:success] = "The todo item has been updated."
  redirect "/lists/#{num}"
end

post "/lists/:num/complete_all" do
  num = params[:num].to_i

  @list = session[:lists][num]
  @items = @list[:todos]

  @items.each { |item| item[:completed] = true }

  session[:success] = "All the todo items have been updated."
  redirect "/lists/#{num}"
end
