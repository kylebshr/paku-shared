# frozen_string_literal: true

Pod::Spec.new do |s|
  s.name          = 'PakuShared'
  s.version       = '0.0.1'
  s.summary       = 'Shared primitives for Paku'
  s.homepage      = 'https://www.github.com/kylebshr/paku-shared'
  s.license       = { :type => 'MIT' }
  s.author        = 'Kyle Bashour'
  s.source        = { git: 'https://github.com/kylebshr/paku-shared.git', tag: s.version }
  s.swift_version = '5.8'
  s.source_files  = 'Sources/PakuShared/**/*.swift'
  s.ios.deployment_target = '15.0'
  s.osx.deployment_target = '12.0'
  s.watchos.deployment_target = '9.0'
end
