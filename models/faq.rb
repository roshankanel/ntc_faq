class Faq
  def initialize(file_path = 'ntc_faq.txt')
    @file_path = file_path # Save the location of our NTC textbook
  end

  # The action where the worker opens the book and reads it out loud
  def read_knowledge_base
    if File.exist?(@file_path)
      File.read(@file_path) # Open and read the book
    else
      "Nepal Telecom provides excellent phone and fiber internet services." # Backup text if book falls on the floor
    end
  end
end