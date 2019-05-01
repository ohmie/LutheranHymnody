require 'nokogiri'
require 'open-uri'

words = Hash.new(0)
dictionary = Hash.new();

def add_word(word, words, file)
	return if word == nil
	word.gsub!(/[“”—,;:\*\.!?]/,'')
	word.gsub!(/’s$/, '')
	word.gsub!(/s’$/, 's')
	words[word] += 1
	#print word, " ", file, "\n" if word.include? "reconciled"
	#print word, " ", file, "\n" if word == "chast’ning"
	#print word, " ", file, "\n" if word.include? "reared"

	#Fix words for 251
end

def add_words(line, words, file)
	line.downcase.split(' ').each do |word|
		if word.include? "—" then
			add_word(word.split('—')[0], words, file)
			add_word(word.split('—')[1], words, file)
		elsif word.include? "-" then
			add_word(word.split('-')[0], words, file)
			add_word(word.split('-')[1], words, file)
		else
			add_word(word, words, file)
		end
	end
end

files = Dir["tlh/tlh???.txt"].each do |file|
	title = nil
	verse = nil
	File.open(file, "r:utf-8").each do |line|
		line.strip!
		next if line == ""
		if title == nil && /^"(.+)"$/ =~ line then
			title = $1
			add_words(title, words, file)
		end
		if /^\(St\. Louis: / =~ line then
			verse = 1
		elsif /^(\d+)\. (.*)$/ =~ line then
			verse = $1
			add_words($2, words, file)
		elsif /\_{5}/ =~ line then
			verse = nil
		elsif verse != nil
			add_words(line, words, file)
		end
	end
end

File.open("dictionary.txt", "r:utf-8").each do |line|
	if /^(.*)->(.*)$/ =~ line then
		dictionary[$1] = $2;
	end
end


words.sort_by{|k,v| v}.each {|k,v|
	#if !dictionary[k] && !k.include?("’") then
	#	##doc = Nokogiri::HTML(open("http://www.thefreedictionary.com/" + k))
	#	##list = doc.xpath("//td//span[@class='hw']/text()")
	#	doc = Nokogiri::HTML(open("http://dictionary.reference.com/browse/" + k))
	#	list = doc.xpath("//div[@class='header']/h2[@class='me']/text()")
	#	word = list[0].to_s
#
#		if word && word != "" then
#			print k, "->", word.gsub(/·/, " -- "), "\n"
#			STDOUT.flush
#		end

#		if word.gsub(/·/, '') == k then
#			print k, "->", word.gsub(/·/, " -- "), "\n"
#			STDOUT.flush
#		elsif word.downcase.gsub(/·/, '') == k then
#			print k, "->", word.downcase.gsub(/·/, " -- "), "\n"
#			STDOUT.flush
		#elsif (word.gsub(/·/, '') + 'ed') == k then
		#	print k, "->", (word.gsub(/·/, " -- ") + 'ed'), "\n"
		#	STDOUT.flush
		#elsif (word.gsub(/·/, '').gsub(/e$/, '') + 'ed') == k then
		#	print k, "->", (word.gsub(/·/, " -- ").gsub(/e$/, '') + 'ed'), "\n"
		#	STDOUT.flush
#		elsif (word.gsub(/·/, '').gsub(/y$/, '') + 'ier') == k then
#			print k, "->", (word.gsub(/·/, " -- ").gsub(/y$/, '') + 'i -- er'), "\n"
#			STDOUT.flush
#		elsif ('un' + word.gsub(/·/, '')) == k then
#			print k, "->", ('un -- ' + word.gsub(/·/, " -- ")), "\n"
#			STDOUT.flush
#		end
#		sleep 1
#	end
	if !dictionary[k] then
		
		print k, "->", k, "\n"
		STDOUT.flush
	end
}
