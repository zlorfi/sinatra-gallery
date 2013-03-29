# Sinatra Gallery App

## Includes
- [Sinatra](http://www.sinatrarb.com)
- [Zurb 4](https://github.com/zurb/foundation)
- [Font-Awesome](http://fortawesome.github.com)
- [Dragonfly](https://github.com/markevans/dragonfly)
- [Mongoid](https://github.com/mongoid/mongoid)
- [jQuery-File-Upload](https://github.com/blueimp/jQuery-File-Upload)
- [fancyBox](https://github.com/fancyapps/fancyBox)

## !!WORK STILL IN PROGRESS!!

## Make it run

- `bundle install`
- start `mongodb`
- create `tmp` and `upload` directories (`mkdir tmp upload`) and make them writable for your Apache
- install ImageMagic (`apt-get -y install imagemagick` or `yum -y install ImageMagick.x86_64`)
- install `memcached` for production caching
- `bundle exec shotgun config.ru` for development (a bit of a warning, `rack_flash` doesn't seem to work with `shotgun`)
- `bundle exec puma config.ru` for production

## TODO
- image handler exception
- store already loaded images in session
- fix a whimsical doubling bug when showing images
- huge multiupload of images causes failed images to load in gallery overview

## Copyright
(The MIT license)

Copyright (C) 2013 Michael Skrynski

See [LICENSE.md](LICENSE.md).
