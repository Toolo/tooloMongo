
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
  IDARRAY = 5
end

def connected_template(template)
  haml :layout, :layout => false do
    haml :connected_layout do
      haml template.to_sym
    end
  end
end

def get_utc_date(value)
  date_parts = value.split(" ")
  date = date_parts[0].split("-")
  time = date_parts[1].split(":")
  new_date = Time.new(date[0].to_i, date[1].to_i, date[2].to_i, time[0].to_i, time[1].to_i, time[2].to_i)
end

def get_type_of_field(value)
  return FieldTypes::IDARRAY if value.class == Array && value[0].class == Hash && value[0].has_key?("$oid")
  return FieldTypes::ID if value.class == Hash && value.has_key?("$oid")
  return FieldTypes::HASH if value.class == Hash 
  return FieldTypes::ARRAY if value.class == Array
  return FieldTypes::DATE if value =~ /\d\d\d\d-\d\d-\d\d\s\d\d:\d\d:\d\d/
  return FieldTypes::STRING
end

def prepare_update_params(update_params)
  type = get_type_of_field(update_params)
  case type
  when FieldTypes::HASH
    update_params.each do |key, value|
      update_params[key] = prepare_update_params(update_params[key])
    end
  when FieldTypes::ID
    update_params = BSON::ObjectId(update_params["$oid"])
  when FieldTypes::ARRAY
    update_params.map do |item|
      prepare_update_params(item)
    end
  when FieldTypes::IDARRAY
    update_params = update_params.map do |item|
      item = BSON::ObjectId(item["$oid"])
    end
  when FieldTypes::DATE
    update_params = get_utc_date(update_params)
  end
  update_params
end

configure do
  set :public_folder, Proc.new { File.join(root, "static") }
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
  input = JSON.parse(params[:jsonDoc])
  coll = session[:db].collection(params[:collection])
  prev_doc = coll.find_one({"_id" => BSON::ObjectId(params[:id])})
  prepare_update_params(input)
  coll.update(prev_doc, input)
  redirect "/collection/#{params[:collection]}"
end

post '/collection/:collection/:id/delete' do
  coll = session[:db].collection(params[:collection]);
  coll.remove({"_id" => BSON::ObjectId(params[:id])})
  redirect "/collection/#{params[:collection]}"
end

