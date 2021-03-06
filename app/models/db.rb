require 'fileutils'

module Hurl
  class AbstractDB
    def self.encode(object)
      Zlib::Deflate.deflate Yajl::Encoder.encode(object)
    end

    def self.decode(object)
      Yajl::Parser.parse(Zlib::Inflate.inflate(object)) rescue nil
    end
  end

  class RedisDB < AbstractDB
    uri = URI.parse(ENV.fetch("REDISTOGO_URL", "redis://127.0.0.1:6379"))
    CONNECTION = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)

    def self.find(scope, id)
      decode(CONNECTION.get("hurl/#{scope}/#{id}"))
    end

    def self.save(scope, id, content)
      CONNECTION.set("hurl/#{scope}/#{id}", encode(content))
    end

    def self.count(scope)
      CONNECTION.keys("hurl/#{scope}/*").size
    end
  end

  class FileDB < AbstractDB
    DIR = File.expand_path(ENV['HURL_DB_DIR'] || "db")

    def self.find(scope, id)
      decode File.read(dir(scope, id) + id) if id && id.is_a?(String)
    rescue Errno::ENOENT
      nil
    end

    def self.save(scope, id, content)
      File.open(dir(scope, id) + id, 'w') do |f|
        f.puts encode(content)
      end

      true
    end

    def self.count(scope)
      files = Dir["#{DIR}/#{scope}/**/**"].reject do |file|
        File.directory?(file)
      end
      files.size
    end

    def self.dir(scope, id)
      path = FileUtils.mkdir_p "#{DIR}/#{scope}/#{id[0...2]}/#{id[2...4]}/"

      # In Ruby 1.9, mkdir_p always returns Array,
      # while in 1.8 it returns String when it has only one item to return.
      if path.is_a? Array
        path[0]
      else
        path
      end
    end
  end

  db_backend = ENV.fetch("DB_BACKEND", "file")
  DB = {
    "file" => FileDB,
    "redis" => RedisDB,
  }.fetch(db_backend)
end
