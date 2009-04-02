#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

require 'rubygems'
require 'sinatra'
require 'yaml'
require 'redcloth'
require 'dm-core'

set YAML.load(open("#{File.dirname(__FILE__)}/setting.yml"))

enable :sessions

configure :test, :development do
  DataMapper.setup(:default, "sqlite3::memory:")
end

configure :production do
  DataMapper.setup(:default, "sqlite3:///#{File.expand_path(File.dirname(__FILE__))}/hamlr.db")
end

configure do
  require 'models'
  DataMapper.auto_upgrade!
end

before do
  AuthToken.delete_old_tokens
  @logged_in = false
  auth_token = AuthToken.first(:token => session['token'])
  if auth_token
    auth_token.expired_at = token_expired_time
    auth_token.save
    @logged_in = true
  end
  content_type "text/html", :charset => "utf-8"
end

get '/' do
  @page = 1
  @entries = Entry.all(:order => [:id.desc], :limit=>options.par_page)
  count = repository(:default).adapter.query('SELECT count(*) FROM entries')[0]
  @page_count = (count / options.par_page.to_f).ceil
  haml "= partial :haml, 'entries', :locals => {:entries => @entries}"
end

get '/page/:page' do
  if params[:page] =~ /\d+/
    @page = params[:page].to_i
    @entries = Entry.all(:order => [:id.desc], :limit => options.par_page, :offset => (@page - 1) * options.par_page)
    count = repository(:default).adapter.query('SELECT count(*) FROM entries')[0]
    @page_count = (count / options.par_page.to_f).ceil
    haml "=partial :haml, 'entries', :locals => {:entries => @entries}"
  else
    redirect '/'
  end
end

get '/search' do
  @q = params[:q] || ''
  @page = 
    if params[:page] && params[:page] =~ /\d+/
      params[:page].to_i
    else
      1
    end
  unless @q.empty?
    @entries = repository(:default).adapter.query(
      'SELECT * FROM entries WHERE title like ? or body like ? limit ? offset ?',
      "%#{@q}%", "%#{@q}%", options.par_page, (@page - 1) * options.par_page)
    count = repository(:default).adapter.query(
      'SELECT count(*) FROM entries WHERE title like ? or body like ?',
      "%#{@q}%", "%#{@q}%")[0]
    @page_count = (count / options.par_page.to_f).ceil
    haml "= partial :haml, 'search', :locals => {:entries => @entries}"
  else
    redirect '/'
  end
end

get '/entry/edit/:id' do
  @entry = Entry.get(params[:id])
  haml "= partial :haml, 'entry/form', :locals => {:action => '/entry/update/#{params[:id]}', :button_label => 'save'}"
end

post '/entry/update/:id' do
  @entry = Entry.get(params[:id])
  @entry.update_attributes(:title=>params[:title], :body=>params[:body])
  redirect "/entry/#{@entry.id}"
end

get '/entry/new' do
  @entry = Entry.new
  haml "= partial :haml, 'entry/form', :locals => {:action=>'/entry/create', :button_label=>'post'}"
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
  content_type 'text/css', :charset => 'utf-8'
  sass :styles
end

helpers do
  def h(str)
    # TODO
    str
  end

  def tx(str)
    if str
      RedCloth.new(str).to_html
    else
      ''
    end
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

