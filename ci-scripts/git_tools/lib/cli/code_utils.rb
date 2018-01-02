# Utitilies for using a ruby script to change the files in the project.
class CodeUtils
  def initialize(log)
    @logger = log
  end

  def change_xcode_version(version)

    @logger.info "XCode CURRENT_PROJECT_VERSION changing to #{version}" 
  	if (ChangeOnFile("../../Register/Register.xcodeproj/project.pbxproj",
  					/CURRENT_PROJECT_VERSION = [1-9]?[1-9]\.[1-9]?[0-9]\.[1-9]?[0-9]/,
  					"CURRENT_PROJECT_VERSION = #{version}"))

      @logger.info "XCode CURRENT_PROJECT_VERSION changed to #{version}"
      return true

    else
      @logger.info "Unable to convert xcode version"
      return false

    end
  end

  def ChangeOnFile(file, regex_to_find, text_to_put_in_place)
   text= File.read file
   File.open(file, 'w+'){|f| f << text.gsub(regex_to_find,
   text_to_put_in_place)}
  end

end
