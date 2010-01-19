# => if file is a directory recurse into it
#    if File.directory?(fullPath)
#      convertFromTo(fullPath, pattern, newExt)
#    else





V2 of the rename - used an array.

######### Original ############
#    @list_array.each do |f|
#      if $replacement == nil
#        newName = f.gsub($pattern,'')
#      else
#        newName = f.gsub($pattern,$replacement)
#      end

#      if f != newName
#        $renamecount += 1
#        File.rename(f,newName)
#      end

#    end #@list_array.each
