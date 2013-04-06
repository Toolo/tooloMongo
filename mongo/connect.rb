require 'mongo'
require 'uri'
require 'json'
 
include Mongo
def get_connection(connectionString)
  return @db_connection if @db_connection
  db = URI.parse(connectionString)
  db_name = db.path.gsub(/^\//, '')
  @db_connection = MongoClient.new(db.host, db.port).db(db_name)
  @db_connection.authenticate(db.user, db.password) unless (db.user.nil? || db.user.nil?)
  @db_connection
end
 

