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
end
