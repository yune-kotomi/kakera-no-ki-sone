require 'shortcut'
require 'native'

module Shortcut
  def self.add(keys, options = {'disable_in_input' => true})
    `shortcut.add(#{keys}, function(){#{yield}}, #{options.to_n})`
    keys = keys.split('+')
    if keys.include?('Ctrl')
      keys.delete('Ctrl')
      keys.push('Meta')
      keys = keys.join('+')
      `shortcut.add(#{keys}, function(){#{yield}}, #{options.to_n})`
    end
  end
end
