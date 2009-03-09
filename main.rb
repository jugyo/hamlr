require 'rubygems'
require 'sinatra'

set :user_id, 'test'
set :password, 'test'

enable :sessions

get '/css' do
  sass :styles
end

get '/login' do
  haml :login
end

post '/login' do
  if auth(params[:user_id], params[:password])
    session['token'] = create_token
    redirect '/'
  else
    redirect '/error'
  end
end

get '/' do
  haml :top
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

def auth(user_id, password)
  options.user_id == user_id && options.password == password
end

def create_token
  'foo'
end
