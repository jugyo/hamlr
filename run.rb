#!/usr/bin/env ruby
# TODO: list.haml => entries.haml
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
set :public, "#{basedir}/public"

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
  @page = 1
  @entries = Entry.all(:order => [:id.desc], :limit=>options.par_page)
  count = repository(:default).adapter.query('SELECT count(*) FROM entries')[0]
  @page_count = (count / options.par_page.to_f).ceil
  haml <<-HAML
= partial :haml, 'entries', :locals => {:entries => @entries}
  HAML
end

get '/page/:page' do
  if params[:page] =~ /\d+/
    @page = params[:page].to_i
    @entries = Entry.all(:order => [:id.desc], :limit => options.par_page, :offset => (@page - 1) * options.par_page)
    count = repository(:default).adapter.query('SELECT count(*) FROM entries')[0]
    @page_count = (count / options.par_page.to_f).ceil
    p @page
    p count
    p @page_count
    haml %q{=partial :haml, 'entries', :locals => {:entries => @entries}}
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
    haml %q{= partial :haml, 'search', :locals => {:entries => @entries}}
  else
    redirect '/'
  end
end

get '/entry/edit/:id' do
  @entry = Entry.get(params[:id])
  haml %q{= partial :haml, 'entry/form', :locals => {:action => '/entry/update/#{params[:id]}', :button_label => 'save'}}
end

post '/entry/update/:id' do
  @entry = Entry.get(params[:id])
  @entry.update_attributes(:title=>params[:title], :body=>params[:body])
  redirect "/entry/#{@entry.id}"
end

get '/entry/new' do
  @entry = Entry.new
  haml %q{= partial :haml, 'entry/form', :locals => {:action=>'/entry/create', :button_label=>'post'}}
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

