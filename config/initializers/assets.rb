# Be sure to restart your server when you modify this file.

# Version of your assets, change this if you want to expire all your assets.
Rails.application.config.assets.version = '1.0'

# Add additional assets to the asset load path
# Rails.application.config.assets.paths << Emoji.images_path
Rails.application.config.assets.paths.concat([
  'vendor/uuidjs/dist',
  'vendor/text-hatena.js',
  'vendor/showdown/dist',
  'vendor/rickdom/src',
  'vendor/mousetrap',
  'vendor/jquery.ex-resize',
  'vendor/jquery-ui',
  'vendor/jquery-ui-touch-punch'
])

# Precompile additional assets.
# application.js, application.css, and all non-JS/CSS in app/assets folder are already added.
# Rails.application.config.assets.precompile += %w( search.js )
