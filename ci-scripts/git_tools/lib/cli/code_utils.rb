# frozen_string_literal: true

# Utitilies for using a ruby script to change the files in the project.
class CodeUtils
  def initialize(log, test_mode)
    @logger = log
    @test_mode = test_mode
  end

  def change_on_file(file, regex_to_find, text_to_put_in_place)
    text = File.read file
    if @test_mode
      @logger.info "TEST_MODE CODE CALL:: #{text.gsub(regex_to_find, text_to_put_in_place)}"
      return true
    end
    File.open(file, 'w+') do |f|
      f << text.gsub(regex_to_find,
                     text_to_put_in_place)
    end
  end
end
