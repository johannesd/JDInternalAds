Pod::Spec.new do |s|
  s.name         = "JDInternalAds"
  s.version      = "0.0.1"
  s.summary      = "JDInternalAds"
  s.description  = <<-DESC
    JDCategories
                   DESC
  s.homepage     = "https://github.com/johannesd/JDInternalAds.git"
  s.license      = { 
    :type => 'Custom permissive license',
    :text => <<-LICENSE
          Free for commercial use and redistribution. No warranty.

        	Johannes Dörr
        	mail@johannesdoerr.de
    LICENSE
  }
  s.author       = { "Johannes Doerr" => "mail@johannesdoerr.de" }
  s.source       = { :git => "https://github.com/johannesd/JDInternalAds.git" }
  s.platform     = :ios, '9.0'
  s.source_files  = '*.{h,m}'

  s.exclude_files = 'Classes/Exclude'
  s.requires_arc = true

  s.dependency 'JDSetFrame'

end
