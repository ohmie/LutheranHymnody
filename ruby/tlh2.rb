numberDictionary = {
	1  => "One",
	2  => "Two",
	3  => "Three",
	4  => "Four",
	5  => "Five",
	6  => "Six",
	7  => "Seven",
	8  => "Eight",
	9  => "Nine",
	10 => "Ten",
	11 => "Eleven",
	12 => "Twelve",
	13 => "Thirteen",
	14 => "Fourteen",
	15 => "Fifteen",
	16 => "Sixteen",
	17 => "Seventeen",
	18 => "Eighteen",
	19 => "Nineteen",
	20 => "Twenty",
}

dictionary = Hash.new()
File.open("dictionary.txt", "r:utf-8").each do |line| 
	if /^(.*)->(.*)$/ =~ line then
		dictionary[$1] = $2
	end
end

meters = Hash.new()
File.open("meters.txt", "r:utf-8").each do |line|
	if /^(\S.*)\t(.+)\t(.+)\t(.*)\t(.*)\t(.*)$/ =~ line then
		meters[$2] = $1
	end
end

extraverses = File.open("extraverses.txt", "r:utf-8").readlines.map do |line|
 line.sub(/\d\/5 2/,"4/5 1")
	.sub(/\d\/[1,2,3,4] [12]/, "")
	.sub(/[1,2,3]\/(\d+ [12])/, '4/\1')
end

headerLookup = {
	"00" => '\LowLowHeader',
	"01" => '\LowHighHeader',
	"10" => '\HighLowHeader',
	"11" => '\HighHighHeader',
}
headers = File.open("headers.txt", "r:utf-8").readlines

def simplify(word, suffix)
	return (word + suffix).gsub(/’/,'\'').gsub(/“”/,'').gsub('ä', 'a').gsub('ö', 'o').gsub('ü', 'u')
end

def clean_music(musicin, oldvoice, newvoice)
	musicin =~ Regexp.new('(' + oldvoice + ' = {.*?})' + "\n", Regexp::MULTILINE)
	return "" unless $1
	sopMusic = $1.gsub(Regexp.new(oldvoice), newvoice)
	#Fix partial measures
	/partial (\d+)\*(\d+)/ =~ sopMusic
	if ($1) then
		partial = $1.to_i / $2.to_i
		sopMusic.gsub!(/partial (\d+)\*(\d+)/, 'partial ' + partial.to_s)
	end
	#Fix sharps and flats
	sopMusic.gsub!(/(\s[a-g])is/, '\1s')
	sopMusic.gsub!(/(\s[a-g])es/, '\1f')
	#Remove Denemo junk
	sopMusic.gsub!(/\\Auto\w*Barline/, '')
	sopMusic.gsub!(/%\d+\n/, '')
	sopMusic.gsub!(/\s+(s\S+\s*)*\s}$/, "\n}\n")
	#Slur tied eigth notes
	if !sopMusic.match?(/\{\s*\\autoBeamOff/) then
		sopMusic.gsub!(/([a-g][sf,']*8)(\s+[a-g][sf,']*)(\s+)([a-g][sf,']*)(\s+[a-g][sf,']*)(\s)/, '\once \omit Slur \1([\2)]\3\once \omit Slur \4([\5)]\6')
		sopMusic.gsub!(/(8\)\s+)([a-g][sf,']*)(\s+[a-g][sf,']*)(\s)/, '\1\once \omit Slur \2(\3)\4')
		sopMusic.gsub!(/([^(]\s+)([a-g][sf,']*8)(\s+[a-g][sf,']*)(\s)/, '\1\once \omit Slur \2(\3)\4')
	end
	#Add end barlines
	replacementtext = newvoice == 'SopMusic' ? ' \bar "|."' + "\n         " + '\1 \2 \bar ".."' + "\n}" : "\n         \\1 \\2\n}"
	sopMusic.gsub!(/\s+(\w+[,']*\d*[.]?)\s+(\w+[,']*\d*[.]?)\s*}/, replacementtext)
	#Remove fermatas
	sopMusic.gsub!('\fermata','') unless newvoice == 'SopMusic'
	#Add clefs
	sopMusic.sub!(/\{/,'{ \clef "treble" \keyTime') if newvoice == 'SopMusic'
	sopMusic.sub!(/\{/,'{ \clef "bass" \keyTime') if newvoice == 'TenorMusic'
	sopMusic.sub!(/\{/,'{ \halfBarBreathMark') if newvoice == 'LineBreaks'
	sopMusic
end

def get_keytime(musicin)
	/(\\key .*?)\s*}/ =~ musicin
	key = $1.gsub(/es/, 'f').gsub(/is/, 's')
	/(\\time .*?)\s*}/ =~ musicin
	time = $1
	if (time == '\time 100/4' || time == '\time 12/4') then
		return 'keyTime = { ' + key + ' \override Staff.TimeSignature.stencil = ##f ' + time + " }\n"
	else
		return 'keyTime = { ' + key + ' \numericTimeSignature ' + time + " }\n"
	end
end

def clean_music_file(tune, appendix)
	filename = 'musicin/' + simplify(tune, appendix) + '.ly'
	return if !File.exists?(filename)
	musicin = File.read(filename)
	keyTime = get_keytime(musicin)
	sopMusic = clean_music(musicin, 'MvmntIVoiceI', 'SopMusic')
	altoMusic = clean_music(musicin, 'MvmntIVoiceII', 'AltoMusic')
	tenorMusic = clean_music(musicin, 'MvmntIVoiceIII', 'TenorMusic')
	bassMusic = clean_music(musicin, 'MvmntIVoiceIV', 'BassMusic')
	lineBreaks = clean_music(musicin, 'LineBreaks', 'LineBreaks')
	alignerVerses = if tune == 'Nicaea' then
		verseOneMusic = "VerseOneMusic = \\SopMusic\n"
		verseTwoMusic = sopMusic.gsub("SopMusic", "VerseTwoMusic").gsub("c''4 ~ c''", "c''4 c''").gsub("ef'' ~ ef''", "ef'' ef''").gsub("bf' ~ bf'", "bf' bf'")
		verseThreeMusic = sopMusic.gsub("SopMusic", "VerseThreeMusic").gsub("c''4 ~ c''", "c''4 c''").gsub("ef'' ~ ef''", "ef'' ef''")
		verseFourMusic = sopMusic.gsub("SopMusic", "VerseFourMusic").gsub("ef'' ~ ef''", "ef'' ef''")
		verseOneMusic + verseTwoMusic + verseThreeMusic + verseFourMusic
	elsif tune == 'St. Louis' then
		verseOneMusic = sopMusic.gsub("SopMusic", "VerseOneMusic").gsub("d''( c'')", "d'' c''")
		verseTwoMusic = "VerseTwoMusic = \\SopMusic\n"
		verseThreeMusic = sopMusic.gsub("SopMusic", "VerseThreeMusic").gsub("d''( c'')", "d'' c''")
		verseFourMusic = sopMusic.gsub("SopMusic", "VerseFourMusic").gsub("d''( c'')", "d'' c''")
		verseOneMusic + verseTwoMusic + verseThreeMusic + verseFourMusic
	elsif tune == 'Stille Nacht' then
		verseOneMusic = sopMusic.gsub("SopMusic", "VerseOneMusic").gsub("a'4\n         g'4.( a'8)", "a'4\n         g'4. a'8").gsub("c''4.( b'8)","c''4. b'8").sub("c''4. b'8","c''4.( b'8)")
		verseTwoMusic = sopMusic.gsub("SopMusic", "VerseTwoMusic").gsub("a'4\n         g'4.( a'8)", "a'4\n         g'4. a'8")
		verseThreeMusic = sopMusic.gsub("SopMusic", "VerseThreeMusic").gsub("c''4.( b'8)", "c''4. b'8")
		verseFourMusic = "VerseFourMusic = \\SopMusic\n"
		verseOneMusic + verseTwoMusic + verseThreeMusic + verseFourMusic
	else
		''
	end
	return (keyTime + sopMusic + altoMusic + tenorMusic + bassMusic + lineBreaks + alignerVerses).encode(Encoding::UTF_8)
end

def hyphenate_word(word, dictionary, hymnNum)
	return "" if word == nil
	return "Cat -- e -- chism -- ’s" if word == "Catechism’s"
	return "Church -- ’s" if word == "Church’s"
	return "Judg -- e’s" if word == "Judge’s"
	puts word if /^\\\w+$/ =~ word
	return word if /^\\\w+$/ =~ word

	simplified_word = word.downcase.gsub(/[“”—,;:\*\.!?]/,'').gsub(/’s$/, '').gsub(/s’$/, 's')
	#puts simplified_word+"\n\n" if simplified_word == "radiance"
	reference_word = if simplified_word == "immanuel" and ['157', '367', '652'].include?(hymnNum) then
		"im -- man -- uel"
	elsif simplified_word == "israel" and ['99', '137', '160', '218', '329', '339', '419', '544'].include?(hymnNum) then
		"is -- rael"
	elsif simplified_word == "pitying" and ['181'].include?(hymnNum) then
		"pit -- y -- ing"
	elsif simplified_word == "loveliest" and ['591'].include?(hymnNum) then
		"love -- li -- est"
	elsif simplified_word == "victorious" and ['239'].include?(hymnNum) then
		"vic -- to -- ri -- ous"
	elsif simplified_word == "glorious" and ['239', '602'].include?(hymnNum) then
		"glo -- ri -- ous"
	elsif simplified_word == "ours" and ['461'].include?(hymnNum) then
		"ou -- rs"
	elsif simplified_word == "abraham" and ['586'].include?(hymnNum) then
		"a -- braham"
	elsif simplified_word == "bethlehem" and ['84'].include?(hymnNum) then
		"beth -- lehem"
	elsif simplified_word == "obedient" and ['131'].include?(hymnNum) then
		"o -- be -- dient"
	else
		dictionary[simplified_word]
	end
	trailing_text = if word.match(/’s$/) then
		"’s"
	elsif word.match(/s’$/)
		"’"
	else
		""
	end
	word = word.gsub(/’s$/, '').gsub(/s’$/, 's')

	# We don't need accent when hyphenated
	word = word.gsub('è', 'e')
	i = 0
	j = 0
	puts word+':'+hymnNum if !reference_word
	while i < reference_word.length do
		while word[j].match(/[“”—,;:\*\.!?]/) do
			j+=1
		end
		if reference_word[i] != word[j].downcase then
			word.insert(j, reference_word[i])
		end
		i+=1
		j+=1
	end
	word + trailing_text
end

def hyphenate_phrase(phrase, dictionary, hymnNum)
	if phrase.include? "—" then
		return hyphenate_word(phrase.split('—')[0], dictionary, hymnNum) + "— " + hyphenate_word(phrase.split('—')[1], dictionary, hymnNum)
	elsif phrase.include? "-" then
		return hyphenate_word(phrase.split('-')[0], dictionary, hymnNum) + " -- " + hyphenate_word(phrase.split('-')[1], dictionary, hymnNum)
	else
		return hyphenate_word(phrase, dictionary, hymnNum)
	end
end

def add_words(line, dictionary, hymnNum)
	line = line.split(' ').map { |phrase| hyphenate_phrase(phrase, dictionary, hymnNum) }.join(' ').gsub(/([Mm]an -- y) (an? )/, '\1_\2').gsub(/( th?’) (\S+)/, '\1_\2').gsub(/([T]h?’) (\S+)/, '\1_\2')
	line.gsub!("praise to", "praise_to") if (hymnNum == '582')
	line
end

def add_verse(verse, lyrics)
	v = []
	verse.each do |line|
		v.push line
	end
	lyrics.push v
	verse.clear()
end

def process_verses(lyrics, dictionary, file, hymnNum, numberDictionary, extraverses)
	new_lyrics = []
	versenum = 1
	verseblock = 1
	lyrics.each do |verse|
		if extraverses[hymnNum.to_i-1] && /^(\d)\/(\d+) ([12])$/ =~ extraverses[hymnNum.to_i-1] && versenum > $1.to_i then
			if verseblock == 1 then
				new_lyrics.push 'VerseBlock' + numberDictionary[verseblock] + ' = \markup {' + "\n"
				new_lyrics.push '  \fill-line {' + "\n"
				new_lyrics.push '    \null' + "\n"
				new_lyrics.push '    \column {' + "\n"
			end
			if versenum != lyrics.size || $3 != '2' || ($2.to_i - $1.to_i) % 2 != 1 then
				new_lyrics.push '    \line {' + "\n"
				new_lyrics.push '      "' + versenum.to_s + "\"\n"
				new_lyrics.push '      \column {' + "\n"
				verse.each do |line|
					new_lyrics.push '        "' + line + "\"\n"
				end
				new_lyrics.push '        \hspace #0' + "\n" if versenum < lyrics.size
				new_lyrics.push '      }' + "\n"
				new_lyrics.push '    }' + "\n"
			end
			if $3 == '2' && verseblock == (($2.to_i - $1.to_i) / 2).floor then
				new_lyrics.push '    }' + "\n"
				new_lyrics.push '    \null' + "\n"
				new_lyrics.push '    \column {' + "\n"
			end
			if versenum == lyrics.size && $3 == '2' && ($2.to_i - $1.to_i) % 2 == 1 then
				new_lyrics.push '    }' + "\n"
				new_lyrics.push '    \null' + "\n"
				new_lyrics.push '  }' + "\n"
				new_lyrics.push '}' + "\n"
				new_lyrics.push 'VerseBlockTwo = \markup {' + "\n"
				new_lyrics.push '  \fill-line {' + "\n"
				new_lyrics.push '    \null' + "\n"
				new_lyrics.push '    \column {' + "\n"
				new_lyrics.push '    \line {' + "\n"
				new_lyrics.push '      "' + versenum.to_s + "\"\n"
				new_lyrics.push '      \column {' + "\n"
				verse.each do |line|
					new_lyrics.push '        "' + line + "\"\n"
				end
				new_lyrics.push '        \hspace #0' + "\n" if versenum < lyrics.size
				new_lyrics.push '      }' + "\n"
				new_lyrics.push '    }' + "\n"
				new_lyrics.push '    }' + "\n"
				new_lyrics.push '    \null' + "\n"
				new_lyrics.push '  }' + "\n"
				new_lyrics.push '}' + "\n"
			elsif versenum == lyrics.size then
				new_lyrics.push '    }' + "\n"
				new_lyrics.push '    \null' + "\n"
				new_lyrics.push '  }' + "\n"
				new_lyrics.push '}' + "\n"
			end
			verseblock += 1
		else
			if (!extraverses[hymnNum.to_i-1] && hymnNum == "558" && (versenum == 2 || versenum == 4 || versenum == 6)) then
				new_lyrics.pop
				new_lyrics.push '\set stanza = #"' + versenum.to_s + '"'
			elsif hymnNum == "629" && versenum == 4 then
				new_lyrics.push 'Verse' + numberDictionary[versenum] + ' = \lyricmode { \set stanza = #"5"'
			else
				new_lyrics.push 'Verse' + numberDictionary[versenum] + ' = \lyricmode { \set stanza = #"' + versenum.to_s + '"'
			end
			verse.each do |line|
				new_lyrics.push "  " + add_words(line, dictionary, hymnNum)
			end
			if (hymnNum == "362") then
				new_lyrics.push " _ _ en " + new_lyrics.last if versenum == 1
				new_lyrics.push " _ _ me, " + new_lyrics.last if versenum == 2
				new_lyrics.push " _ _ est; " + new_lyrics.last if versenum == 3
				new_lyrics.push " A -- men. sures. " + new_lyrics.last + " A -- men." if versenum == 4
			elsif (hymnNum == "615") then
				new_lyrics.push " _ _ ed. " + new_lyrics.last if versenum == 1
				new_lyrics.push " _ _ ing; " + new_lyrics.last if versenum == 2
				new_lyrics.push " _ _ you, " + new_lyrics.last if versenum == 3
				new_lyrics.push " A -- men. ness— " + new_lyrics.last + " A -- men." if versenum == 4
			elsif (hymnNum == "315" || hymnNum == "247") then
				# Put at the end of the refrain on verse one
				new_lyrics.push "  A -- men." if versenum == 1
			elsif versenum == lyrics.size || (extraverses[hymnNum.to_i-1] && versenum == $1.to_i) then
				new_lyrics.push "  A -- men."
			end
			new_lyrics.push '}'
			#lyrics.push v
		end
		versenum += 1
	end
	new_lyrics
end

def lookup_sections(hymnNum)
	case hymnNum
		when 1..6 then ['Adoration', 'Opening of Service', '1–6']
		when 7..12 then ['Adoration', 'Lord’s Day', '7–12']
		when 13..44 then ['Adoration', 'Worship and Praise', '13–44']
		when 45..54 then ['Adoration', 'Close of Service', '45–54']
		when 55..75 then ['The Church Year', 'Advent', '55–75']
		when 76..109 then ['The Church Year', 'Christmas', '76–109']
		when 110..113 then ['The Church Year', 'New Year’s Eve', '110–113']
		when 114..125 then ['The Church Year', 'New Year', '114–125']
		when 126..134 then ['The Church Year', 'Epiphany', '126–134']
		when 135 then ['The Church Year', 'Transfiguration', '135']
		when 136..139 then ['The Church Year', 'Presentation', '136–139']
		when 140..159 then ['The Church Year', 'Lent', '140–159']
		when 160..162 then ['The Church Year', 'Palm Sunday', '160–162']
		when 163..164 then ['The Church Year', 'Maundy Thursday', '163–164']
		when 165..186 then ['The Church Year', 'Good Friday', '165–186']
		when 187..211 then ['The Church Year', 'Easter', '187–211']
		when 212..223 then ['The Church Year', 'Ascension', '212–223']
		when 224..236 then ['The Church Year', 'Pentecost', '224–236']
		when 237..253 then ['The Church Year', 'Trinity', '237–253']
		when 254..257 then ['The Church Year', 'St. Michael’s and All Angels', '254–257']
		when 258..269 then ['The Church Year', 'Reformation', '258–269']
		when 270 then ['The Church Year', 'St. Andrew', '270']
		when 271 then ['The Church Year', 'St. John the Apostle', '271']
		when 272 then ['The Church Year', 'St. John the Baptist', '272']
		when 273 then ['The Church Year', 'Holy Innocents', '273']
		when 274 then ['The Church Year', 'Annunciation', '274']
		when 275 then ['The Church Year', 'Visitation', '275']
		when 276..281 then ['Invitation', '', '276–281']
		when 282..297 then ['The Word', 'Law and Gospel', '282–297']
		when 298..303 then ['The Sacraments', 'Baptism', '298–303']
		when 304..316 then ['The Sacraments', 'Lord’s Supper', '304–316']
		when 317..331 then ['Confession and Absolution', '', '317–331']
		when 332..338 then ['Confirmation', '', '332–338']
		when 339..368 then ['The Redeemer', '', '339–368']
		when 369..392 then ['Faith and Justification', '', '369–392']
		when 393..405 then ['Sanctification', 'Consecration', '393–405']
		when 406..424 then ['Sanctification', 'New Obedience', '406–424']
		when 425..437 then ['Sanctification', 'Trust', '425–437']
		when 438..443 then ['Sanctification', 'Stewardship', '438–443']
		when 444..453 then ['Sanctification', 'Christian Warfare', '444–453']
		when 454..459 then ['Prayer', '', '454–459']
		when 460..481 then ['The Church', 'Communion of Saints', '460–481']
		when 482..493 then ['The Church', 'Ministry', '482–493']
		when 494..512 then ['The Church', 'Missions', '494–512']
		when 513..535 then ['Cross and Comfort', '', '513–535']
		when 536..550 then ['Times and Seasons', 'Morning', '536–550']
		when 551..565 then ['Times and Seasons', 'Evening', '551–565']
		when 566..574 then ['Times and Seasons', 'Harvest and Thanksgiving', '566–574']
		when 575..584 then ['Times and Seasons', 'The Nation', '575–584']
		when 585..602 then ['The Last Things', 'Death and Burial', '585–602']
		when 603 then ['The Last Things', 'Resurrection', '603']
		when 604..612 then ['The Last Things', 'Judgment', '604–612']
		when 613..619 then ['The Last Things', 'Life Everlasting', '613–619']
		when 620..623 then ['The Christian Home', 'Marriage', '620–623']
		when 624..626 then ['The Christian Home', 'The Family', '624–626']
		when 627..631 then ['The Christian Home', 'Christian Education', '627–631']
		when 632..633 then ['Special Occasions', 'Cornerstone Laying', '632–633']
		when 634..638 then ['Special Occasions', 'Dedication', '634–638']
		when 639..640 then ['Special Occasions', 'Church Anniversary', '639–640']
		when 641 then ['Special Occasions', 'Theological Institutions', '641']
		when 642 then ['Special Occasions', 'Foreign Missionaries', '642']
		when 643 then ['Special Occasions', 'Absent Ones', '643']
		when 644 then ['Special Occasions', 'The Long-Meter Doxology', '644']
		when 645..660 then ['Carols and Spiritual Songs', '', '645–660']
		when 661 then ['The Litany', '', '661']
		when 662..668 then ['Chants', '', '662–668']
		else ['', '', '']
	end
end

def print_ly_file(f, hymnNum, headerstyle, title, text, titled, author, author2, author3, translatedby, translatedby2, tunenumber, tune, appendix, overridemeter, lyrics)
	hymn = [title] + lookup_sections(hymnNum.to_i)
	subsection = hymn[2] != '' ? hymn[2] : hymn[1]
	f.puts '\version "2.19.82"'
	f.puts '\include "../framework/header.ly"'
	f.puts 'headerStyle = ' + headerstyle
	f.puts
	f.puts 'hymnNum = "' + hymnNum + '"'
	f.puts 'subsection = "' + subsection.upcase + '"'
	f.puts 'title = "' + title + '"'
	f.puts 'scripture = "' + text + '"' if text
	f.puts 'originaltitle = "' + titled + '"' if titled
	f.puts 'author = "' + author + '"' if author
	f.puts 'authorTwo = "' + author2 + '"' if author2
	f.puts 'authorThree = "' + author3 + '"' if author3
	f.puts 'translator = "' + translatedby + '"' if translatedby
	f.puts 'translatorTwo = "' + translatedby2 + '"' if translatedby2
	f.puts tunenumber if tunenumber
	f.puts
	f.puts '\include "../tunes/' + simplify(tune, appendix) + '.ly"' if tune
	f.puts 'meter = "' + overridemeter + '"' if overridemeter
	f.puts
	f.puts lyrics
	f.puts
	if tune == "Nicaea" or tune == "St. Louis" or tune == "Stille Nacht" then
		f.puts 'NullOne = \new NullVoice = "verseOne" { \voiceOne \VerseOneMusic }'
		f.puts 'NullTwo = \new NullVoice = "verseTwo" { \voiceOne \VerseTwoMusic }'
		f.puts 'NullThree = \new NullVoice = "verseThree" { \voiceOne \VerseThreeMusic }'
		f.puts 'NullFour = \new NullVoice = "verseFour" { \voiceOne \VerseFourMusic }'
		f.puts 'VerseOneLyrics = \new Lyrics \lyricsto "verseOne" { \VerseOne }'
		f.puts 'VerseTwoLyrics = \new Lyrics \lyricsto "verseTwo" { \VerseTwo }'
		f.puts 'VerseThreeLyrics = \new Lyrics \lyricsto "verseThree" { \VerseThree }'
		f.puts 'VerseFourLyrics = \new Lyrics \lyricsto "verseFour" { \VerseFour }'
		f.puts 'VerseFiveLyrics = \new Lyrics \lyricsto "verseOne" { \VerseFive }'
		f.puts '\include "../framework/framework.ly"'
	else
		f.puts 'NullOne = \new NullVoice = "aligner" { \voiceOne \SopMusic }'
		f.puts 'NullTwo = \new NullVoice {}'
		f.puts 'NullThree = \new NullVoice {}'
		f.puts 'NullFour = \new NullVoice {}'
		f.puts 'VerseOneLyrics = \new Lyrics \lyricsto "aligner" { \VerseOne }'
		f.puts 'VerseTwoLyrics = \new Lyrics \lyricsto "aligner" { \VerseTwo }'
		f.puts 'VerseThreeLyrics = \new Lyrics \lyricsto "aligner" { \VerseThree }'
		f.puts 'VerseFourLyrics = \new Lyrics \lyricsto "aligner" { \VerseFour }'
		f.puts 'VerseFiveLyrics = \new Lyrics \lyricsto "aligner" { \VerseFive }'
		f.puts '\include "../framework/framework.ly"'
	end
end

files = Dir["tlh/tlh???.txt"].each do |file|
	#puts file
	test1 = false
	title = nil
	versenum = nil
	hymnNum = nil
	lyrics = []
	verse = []
	text = nil
	titled = nil
	author = nil
	author2 = nil
	author3 = nil
	translatedby = nil
	translatedby2 = nil

	meter = nil
	overridemeter = nil
	tune = nil
	firstpublishedin = nil
	firstpublishedin2 = nil
	town = nil
	composer = nil
	composer2 = nil
	arrangedby = nil
	secondtune = nil
	thirdtune = nil
	secondtunecomposer = nil
	thirdtunecomposer = nil
	File.open(file, "r:utf-8").each do |line|
		line.strip!
		next if line == ""
		if title == nil && /^"(.+)"$/ =~ line then
			title = $1
	#		print file, " ", title, "\n"
			#add_words(title, words, file)
		end
		if /^REFRAIN: (.*)$/ =~ line then
			line = $1
			line = "\\dropThreeLyrics " + line + " \\raiseLyrics" if line.match?("Oh, let us perish")
			line = "\\dropFourLyrics Lord, may Thy body and Thy \\raiseLyrics blood" if line.match?("Lord, may Thy body")
			verse.push line
		elsif /^(\d+)\. (.*)$/ =~ line then
			add_verse(verse, lyrics) if verse.size > 0
			
			versenum = $1
			verse.push $2
			##lyrics.push '}' if versenum.to_i > 1
			##lyrics.push 'Verse' + numberDictionary[versenum.to_i] + ' = \lyricmode { \set stanza = #"' + versenum + '"'
			##lyrics.push "  " + add_words($2, dictionary, file)
		elsif /\_{5}/ =~ line then
			##lyrics.push '}' if versenum != nil
			add_verse(verse, lyrics) if verse.size > 0
			versenum = nil
			test1 = !test1
		elsif versenum != nil
			##lyrics.push "  " + add_words(line, dictionary, file)
			verse.push line
		elsif /^\s*Hymn #(\d+)/ =~ line then
			hymnNum = $1
		elsif /^\s*Text: (.*)$/ =~ line then
			text = $1
		elsif /^\s*Titled: "?(.*?)"?$/ =~ line then
			titled = $1
		elsif /^\s*Author: (.*)$/ =~ line then
			author = $1
		elsif /^\s*Author2: (.*)$/ =~ line then
			author2 = $1
		elsif /^\s*Author3: (.*)$/ =~ line then
			author3 = $1
		elsif /^\s*Translated by: (.*)$/ =~ line then
			translatedby = $1
		elsif /^\s*Translated by2: (.*)$/ =~ line then
			translatedby2 = $1
		elsif /^\s*Meter: (.*)$/ =~ line then
			overridemeter = $1
		elsif /^\s*(First )?Tune: "?(.*?)"?\s*$/ =~ line then
			tune = $2
		elsif /^\s*Second Tune: "?(.*?)"?\s*$/ =~ line then
			secondtune = $1
		elsif /^\s*(First Tune )?1st Published in: (.*)$/ =~ line then
			firstpublishedin = $2
		elsif /^\s*1st Published in2: (.*)$/ =~ line then
			firstpublishedin2 = $1
		elsif /^\s*(First Tune )?Town: (.*)$/ =~ line then
			town = $2
		elsif /^\s*(First Tune )?Composer: (.*)$/ =~ line then
			composer = $2
		elsif /^\s*Composer2: (.*)$/ =~ line then
			composer2 = $1
		elsif /^\s*Second Tune Composer: (.*)$/ =~ line then
			secondtunecomposer = $1
		elsif /^\s*Third Tune Composer: (.*)$/ =~ line then
			thirdtunecomposer = $1
		elsif /^\s*(First Tune )?Arranged by: (.*)$/ =~ line then
			arrangedby = $2
		else
			if test1 && !(/Hymnal/ =~ line) then
			/^\s*(.*):/ =~ line
			print file, " ", $1, "\n" if $1 != "Notes"
			end
		end
	end
	meter = meters[simplify(tune, "")]
	meter = "8s. 10 lines" if hymnNum == "251"
	secondtune = tune if secondtunecomposer != nil && secondtune == nil
	thirdtune = tune if thirdtunecomposer != nil && thirdtune == nil
	(translatedby = "Tr., " + translatedby) if translatedby
	(arrangedby = "Arr. by " + arrangedby) if arrangedby
	(translatedby2 = "Tr., " + translatedby2) if (translatedby2 && hymnNum != "254")
	(translatedby2 = "English tr., " + translatedby2) if (translatedby2 && hymnNum == "254")
	if firstpublishedin then
		firstpublishedin.sub!('_', '“')
		firstpublishedin.sub!('"', '“')
		firstpublishedin.sub!('_', '”') 
		firstpublishedin.sub!('"', '”')
	end
	if firstpublishedin2 then
		firstpublishedin2 = firstpublishedin2.reverse.sub('_', "”").sub('"', "”").reverse
		firstpublishedin.sub!('_', '“')
		firstpublishedin.sub!('"', '“')
	end
	ly_lyrics = process_verses(lyrics, dictionary, file, hymnNum, numberDictionary, extraverses)
	puts file + " " + arrangedby if arrangedby && arrangedby.include?('41')

#puts tune if !File.exists?('musicin/' + simplify(tune) + '.ly')
    appendix = ""
	appendix = " (First Tune)" if hymnNum == "73"
	appendix = " (10 lines) (First Tune)" if hymnNum == "251"
	appendix = " (6 lines)" if hymnNum == "252"
	appendix = " 2" if hymnNum == "477"
	appendix = " 2" if hymnNum == "624"
	appendix = " (Konig)" if (hymnNum == "30" || hymnNum == "88" || hymnNum == "385")
	if File.exists?('musicin/' + simplify(tune, appendix) + '.ly') then
		File.open('ly/' + hymnNum + '.ly', "w:utf-8") do |f|
			headerstyle = headerLookup[headers[hymnNum.to_i - 1][0..1]]
			tunenumber = 'tuneNumber = "(FIRST TUNE)"' if secondtune
			print_ly_file(f, hymnNum, headerstyle, title, text, titled, author, author2, author3, translatedby, translatedby2, tunenumber, tune, appendix, overridemeter, ly_lyrics)
		end
		File.open('tunes/' + simplify(tune, appendix) + '.ly', "w:utf-8") do |f|
			f.puts 'tune = "' + tune + '"'
			f.puts 'meter = "' + meter + '"' if meter
			f.puts 'published = "' + firstpublishedin + '"' if firstpublishedin
			f.puts 'publishedTwo = "' + firstpublishedin2 + '"' if firstpublishedin2
			f.puts 'town = "' + town + '"' if town
			f.puts 'composer = "' + composer + '"' if composer
			f.puts 'composerTwo = "' + composer2 + '"' if composer2
			f.puts 'arrangedBy = "' + arrangedby + '"' if arrangedby
			f.puts
			f.puts clean_music_file(tune, appendix)
		end
		if secondtune then
			appendix = " (Second Tune)" if hymnNum == "73"
			appendix = " (10 lines) (Second Tune)" if hymnNum == "251"
			ly_lyrics = process_verses(lyrics, dictionary, file, hymnNum, numberDictionary, []) if hymnNum == "558"
			meter = meters[simplify(secondtune, "")] if secondtune

			File.open('ly/' + hymnNum + 'b.ly', "w:utf-8") do |f|
				headerstyle = headerLookup[headers[hymnNum.to_i - 1][2..3]]
				tunenumber = 'tuneNumber = "(SECOND TUNE)"' if secondtune
				print_ly_file(f, hymnNum, headerstyle, title, text, titled, author, author2, author3, translatedby, translatedby2, tunenumber, secondtune, appendix, overridemeter, ly_lyrics)
			end
			File.open('tunes/' + simplify(secondtune, appendix) + '.ly', "w:utf-8") do |f|
				f.puts 'tune = "' + secondtune + '"'
				f.puts 'meter = "' + meter + '"' if meter
				f.puts 'composer = "' + secondtunecomposer + '"' if secondtunecomposer
				f.puts
				f.puts clean_music_file(secondtune, appendix)
			end
		end
		if thirdtune then
			appendix = " (Third Tune)" if hymnNum == "73"
			File.open('ly/' + hymnNum + 'c.ly', "w:utf-8") do |f|
				headerstyle = headerLookup[headers[hymnNum.to_i - 1][4..5]]
				tunenumber = 'tuneNumber = "(THIRD TUNE)"' if secondtune
				print_ly_file(f, hymnNum, headerstyle, title, text, titled, author, author2, author3, translatedby, translatedby2, tunenumber, thirdtune, appendix, overridemeter, ly_lyrics)
			end
			File.open('tunes/' + simplify(thirdtune, appendix) + '.ly', "w:utf-8") do |f|
				f.puts 'tune = "' + thirdtune + '"'
				f.puts 'meter = "' + meter + '"' if meter
				f.puts 'composer = "' + thirdtunecomposer + '"' if thirdtunecomposer
				f.puts
				f.puts clean_music_file(thirdtune, appendix)
			end
		end
	end
	#puts f if author == nil
	#puts f if titled != nil && titled.include?('Σ')

end