#!/usr/bin/env ruby

require 'rubygems' unless RUBY_VERSION >= '1.9'
require "./app"

App::Picture.all.each do |p|
  if p.delete
    begin
      File.delete("./upload/#{p.image_uid}")
      p "File: #{p.image_uid} deleted"
    rescue => e
      p e.message
    end
  end
end

Dir.glob('./seed_files/*.gif') do |file|
  app = Dragonfly[:images].configure_with(:imagemagick)
  prepared_image = app.fetch_file(file).process!(:resize, '1000x1000>')
  image_uid = app.store(prepared_image)
  picture = App::Picture.create(image_uid: image_uid, sort_key: App::Picture.get_highest_key)
  p "Picture with ID #{picture.id} inserted"
end

def run(command)
  result = system(command)
  raise("error, process exited with status #{$?.exitstatus}") unless result
end

cmd = "bundle exec puma config.ru"
run cmd
