
require 'rubygems'
require 'sinatra'
require 'haml'

load 'mongo/connect.rb'


module FieldTypes
  HASH = 0
  STRING = 1
  DATE = 2
  ID = 3
  ARRAY = 4
end

def connected_template(template)
  haml :layout, :layout => false do
    haml :connected_layout do
      haml template.to_sym
    end
  end
end

def get_type_of_field(key, value)
  return FieldTypes::ID if value.class == Hash && value.has_key?("$oid")
  return FieldTypes::HASH if value.class == Hash 
  return FieldTypes::ARRAY if value.class == Array
  return FieldTypes::DATE if value =~ /\d\d\d\d-\d\d-\d\d\s\d\d:\d\d:\d\d/
  return FieldTypes::STRING if key != "$oid"
  
end

def get_utc_date(value)
  date_parts = value.split(" ")
  date = date_parts[0].split("-")
  time = date_parts[1].split(":")
  new_date = Time.new(date[0].to_i, date[1].to_i, date[2].to_i, time[0].to_i, time[1].to_i, time[2].to_i)
end

def prepare_update_params(update_params)
  update_params.each do |key, value|
    puts key
    type = get_type_of_field(key, value)
    case type
    when FieldTypes::HASH
      puts "Hash, recursive call", update_params[key]
      prepare_update_params(value)
      puts "Hash, done", update_params[key]
    when FieldTypes::DATE
      update_params[key] = get_utc_date(value)
#    when FieldTypes::STRING
    when FieldTypes::ID
      puts "ID in", value
      value.delete("$oid")
      if value.keys.count == 0
        puts "I SHOULD DELETE ME MAN"
        update_params.delete(key)
      end
      puts "ID out", value
    when FieldTypes::ARRAY
      puts "ARRAY"
    end
  end
end

configure do
  set :public_folder, Proc.new { File.join(root, "static") }
  set :my_config_property, 'hello world'
  use Rack::Session::Pool, :expire_after => 2592000
end

get '/' do
  haml :connect
end

post '/' do
  session[:db] = get_connection(params[:connectionString])
  connected_template("index")
end

get '/collection/:collection' do
  coll = session[:db].collection(params[:collection])
  @docs = coll.find()
  connected_template("collection")
end

get '/collection/:collection/:id/edit' do
  @doc = session[:db].collection(params[:collection]).find_one({"_id" => BSON::ObjectId(params[:id])})
  connected_template("editDoc")
end

post '/collection/:collection/:id/edit' do
  id = params[:id]
  input = JSON.parse(params[:jsonDoc])
  puts input
  prev_doc = session[:db].collection(params[:collection]).find_one({"_id" => BSON::ObjectId(params[:id])})

  coll = session[:db].collection(params[:collection])
  prepare_update_params(input)
  puts input
  #coll.update(input, prev_doc)
  redirect "/collection/#{params[:collection]}"
end