#
# Be sure to run `pod lib lint XKDataSQLite.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'XKDataSQLite'
  s.version          = '1.0.0'
  s.summary          = '数据库操作工具'

  s.homepage         = 'https://github.com/RyanMans/XKDataSQLite'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'ALLen、LAS' => '1696186412@qq.com' }
  s.source           = { :git => 'https://github.com/ryanmans/XKDataSQLite.git', :tag => s.version.to_s }
  
  s.ios.deployment_target = '8.0'
  s.source_files = 'XKDataSQLite/Classes/**/*'
  
  s.frameworks = 'UIKit', 'Foundation'
  s.dependency 'FMDB'
end
