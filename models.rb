class Entry
  include DataMapper::Resource
  property :id,         Serial
  property :title,      String
  property :body,       Text
  property :created_at, DateTime
  property :updated_at, DateTime

  has n, :comments
  has n, :taggings
  has n, :tags, :through => :taggings
end

class Comment
  include DataMapper::Resource
  property :id,         Serial
  property :name,       String
  property :email,      String
  property :url,        String
  property :body,       Text

  belongs_to :entry
end

class Tag
  include DataMapper::Resource
  property :id,         Serial
  property :name,       String

  has n, :taggings
  has n, :entries, :through => :taggings
end

class Tagging
  include DataMapper::Resource
 
  belongs_to :tag
  belongs_to :entry
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
