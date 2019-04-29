--string ext

function string.split(str, split)
    local splitlist = {}
    string.gsub(str, '[^'..split..']+', function(w) table.insert(splitlist, w) end )
	return splitlist
end

function string.coventable(table)
    return require "pb/serpent".block(table)
end