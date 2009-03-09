require 'rubygems'
require 'dm-core'
require 'sinatra'

# TODO: 古いトークンの削除

# Init for DataMapper
DataMapper.setup(:default, "sqlite3:///#{File.expand_path(File.dirname(__FILE__))}/db/hamlog.db")
#DataObjects::Sqlite3.logger = DataObjects::Logger.new(STDOUT, :debug)
require 'models'
DataMapper.auto_upgrade!

set :user_id, 'test'
set :password, 'test'

enable :sessions

before do
  AuthToken.delete_old_tokens
  @logged_in = false
  auth_token = AuthToken.first(:token => session['token'])
  if auth_token
    auth_token.expired_at = token_expired_time
    auth_token.save
    @logged_in = true
  end
end

get '/' do
  haml :top
end

get '/login' do
  if @logged_in
    redirect '/'
  else
    haml :login
  end
end

post '/login' do
  if @logged_in
    redirect '/'
  elsif auth(params[:user_id], params[:password])
    auth_token = AuthToken.new(:token=>AuthToken.generate_token, :expired_at=>token_expired_time)
    session['token'] = auth_token.token
    auth_token.save
    redirect '/'
  else
    redirect '/error'
  end
end

get '/logout' do
  auth_token = AuthToken.first(:token => session['token'])
  if auth_token
    auth_token.destroy
  end
  redirect '/'
end

get '/css' do
  sass :styles
end

helpers do
  def partial(renderer, template, options = {})
    options = options.merge({:layout => false})
    template = "_#{template.to_s}".to_sym
    m = method(renderer)
    m.call(template, options)
  end

  def partial_haml(template, options = {})
    partial(:haml, template, options = {})
  end

  def partial_erb(template, options)
    partial(:erb, template, options)
  end
end

def token_expired_time
  DateTime.now + 60 * 60 * 24
end

def auth(user_id, password)
  options.user_id == user_id && options.password == password
end

