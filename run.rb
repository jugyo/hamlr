#!/usr/bin/env ruby

require 'rubygems'
require 'dm-core'
require 'sinatra'
require 'yaml'
require 'redcloth'

basedir = File.expand_path(File.dirname(__FILE__))

# Init for DataMapper
DataMapper.setup(:default, "sqlite3:///#{basedir}/hamlog.db")
#DataObjects::Sqlite3.logger = DataObjects::Logger.new(STDOUT, :debug)
require 'models'
DataMapper.auto_upgrade!

set YAML.load(open("#{basedir}/conf.yml"))

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
  @entries = Entry.all(:order => [:id.desc], :limit=>10)
  haml :top
end

get 'search' do
  # TODO
end

get '/entry/edit/:id' do
  @entry = Entry.get(params[:id])
  haml :entry
end

post '/entry/upadte/:id' do
  # TODO
  @entry = Entry.get(params[:id])
  @entry.update_attributes(params[:entry])
  redirect :"entry/#{@entry.id}"
end

get '/entry/new' do
  haml :'entry/new'
end

post '/entry/create' do
  e = Entry.create(params)
  redirect "/entry/#{e.id}"
end

get '/entry/:id' do
  @entry = Entry.get(params[:id])
  haml :'entry/show'
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
  def h(str)
    # TODO
    str
  end

  def tx(str)
    RedCloth.new(str).to_html
  end

  def partial(renderer, template, options = {})
    options = options.merge({:layout => false})
    template = "#{template.to_s}".to_sym
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

