get '/sample' do
  {:theme => options.theme, :plugins => options.plugins}.inspect
end
