require 'dm-core'

class Entry
  include DataMapper::Resource
  property :id,         Serial
  property :title,      String
  property :body,       Text
  property :created_at, DateTime
  property :updated_at, DateTime
end

class AuthToken
  include DataMapper::Resource
  property :id,         Serial
  property :token,      String
  property :expired_at, DateTime

  class << self
    def delete_old_tokens
      self.all(:expired_at.lt => DateTime.now).each do |token|
        token.destroy
      end
    end

    def generate_token(length=32)
      alphanumerics = ('a'..'z').to_a.concat(('A'..'Z').to_a.concat(('0'..'9').to_a))
      alphanumerics.sort_by{rand}.to_s[0..length]
    end
  end
end

DataMapper.setup(:default, "sqlite3:///#{File.dirname(__FILE__)}/hamlr.db")
#DataObjects::Sqlite3.logger = DataObjects::Logger.new(STDOUT, :debug)
DataMapper.auto_upgrade!
