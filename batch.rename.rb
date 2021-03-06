#!/usr/bin/ruby

########################
##=   Batch Rename   =##
########################
$version = "1.6.118"
# 
# Batch Rename is a substitution based batch file renamer with 
# additional modes & options. The basic mode of use is the given
# REPLACEMENT text replaces the PATTERN text in all filenames in
# the current working  Pdirectory.
#
# Written by Matt Jordan -
# Insipred by Dmitry Nedospasov's batch rename script at:
# http://nedos.net/2009/02/20/ruby-batch-rename-script/

require 'rubygems'
require 'ftools'
require 'Getopt/Declare'
require 'ostruct'

# Parse cli options into the $op OpenStruct with GetoptDeclare.
$op = OpenStruct.new
args = Getopt::Declare.new(<<'EOF')

-i                  invert [requires: (-u || --uppercase) || (-l || --lowercase)] [excludes: -a --all]
{ $op.invert = 1 }
--invert            [ditto]

-c                  ignore Pattern Case
{ $op.ignore_case = 1 }
--case              [ditto]

--debug              DEBUG
{ $op.debug = 1 }

-u                  upcase [excludes: -l --lowercase]
{ $op.upcase = 1 }
--uppercase         [ditto]

-l                  lowercase [excludes: -u --uppercase]
{ $op.downcase = 1}
--lowercase         [ditto]

-a                  all
{ $op.all = 1}
--all               [ditto]

-v                  Version
{ $op.version = 1 }
--version           [ditto]

-V                  Verbose [excludes: -q --quiet]
{ $op.verbose = 1 }
--verbose           [ditto]

-q                  Quiet [excludes: -V --verbose]
{ $op.quiet = 1 }
--quiet             [ditto]

-h                  Help
{ $op.help = 1 }
--help              [ditto]

-t <value:i>        Trim
{ $op.trim = value ; $op.trimt = 1}
--trim              [ditto]

-d                  Directories
{ $op.dirs = 1 }
--dirs              [ditto]

-D                  Only Directories
{ $op.only_dirs = 1 }
--only_dirs         [ditto]

-A                  Append
{ $op.append = 1 }
--append            [ditto]

-P                  Prepend
{ $op.prepend = 1 }
--prepend           [ditto]

-F                  Force
{ $op.force = 1 }
--force             [ditto]

-c                  Confirm
{ $op.confirm = 1 }
--confirm           [ditto]

-s                  Step-Confirm
{ $op.step = 1 }
--step              [ditto]

EOF

class String
  def to_regexp
    return Regexp.new(self) unless
    self.strip.match(/\A\/(.*)\/(.*)\Z/mx)
    regexp , flags = $1 , $2
    return nil if !regexp || flags =~ /[^xim]/m

    x = /x/.match(flags) && Regexp::EXTENDED
    i = /i/.match(flags) && Regexp::IGNORECASE
    m = /m/.match(flags) && Regexp::MULTILINE

    Regexp.new regexp , [x,i,m].inject(0){|a,f| f ? a+f : a }
  end
end

module Output

  # method to print usage when $op.usage is set. Will execute code given in block.
  def print_usage
    debug("print_usage")

    loud('Usage: batch.rename [-acDilqtuvV] <PATTERN> <REPLACEMENT>')
    block_given? ? yield : {}
  end

  # method to print version when $op.version is set. Will execute code given in block.
  def print_version
    debug("print_version")

    puts "Batch Rename v. #{$version}\n"
    block_given? ? yield : {}
  end

  # method to print info when $op.debug is set. Will execute code given in block.
  def debug(i)
    # $op.debug == 1 ? puts("==== #{i} ====") : {}
  end

  # method to print info when $op.verbose is set
  def verbose(i)
    $op.verbose == 1 ? puts(i) : {}
  end

  # method to print info when $op.quiet is not set
  def loud(i)
    $op.quiet != 1 ? puts(i) : {}
  end

  # method to print help when $op.help is set. Will execute code given in block.
  def print_help
    debug("printing help")

    print_version
    print_usage

    puts <<END

  Batch Rename is a substitution based batch file renamer with additional modes & options.
  Typically REPLACEMENT replaces the PATTERN for all filenames in the local directory.  To delete
  the PATTERN from the file names, do not enter a REPLACEMENT.  When the editing mode is changed,
  PATTERN acts as a search filter.  All whitespaces inside the PATTERN or REPLACEMENT should be
  escaped with a backslash (\\), or the whole phrase should be in quotation marks.

  -t <num> --trim <num> Trim Mode: +number of characters from end or -number characters from beginning.
  -u --upperercase      Uppercase mode. Change filenames to uppercase. Requires PATTERN or the -all option.
  -l --lowercase        Lowercase mode. Change filenames to lowercase. Requires PATTERN or the -all option.
  -A --append           Append mode.  -A <PATTERN> <REPLACEMENT>  or  -Aa <REPLACEMENT>.
  -P --prepend          Prepend mode.  -P <PATTERN> <REPLACEMENT>  or  -Pa <REPLACEMENT>.

  -d --dirs             Include directories in PATTERN search.  Off by default.
  -D --only-dirs        Exclude all except directories in PATTERN search.
  -a --all              Disregard PATTERN, include all files in edit.
  -i --invert           Invert results from PATTERN.  Not compatible with all options.
  -c --case             Ignore case of PATTERN.
  -F --force            Force file name clobbering. Use with great care...

  -c --confirm          Confirmation prompt with report before proceeding with operation.
  -s --step             Confirmation prompts given file by file.
  -v --version          Print program version.
  -V --verbose          Verbose output.
  -q --quiet            Quiet output.
  -h --help             Print this help.
     --debug            Print debug dialogues.
END

  # --index            planned, not implimented
  # -X                 planned, only affect extensions
  # -x                 planned, preserve extensions
  # --propercase       planned
  #                    planned, add extension to files lacking them
  # -s --step          planned, step confirmation of each file rename
  # -c --confirmation  planned, confirm results before proceeding with rename
  # -t --test          planned, dry run of rename, with printed results
  # -r --regex         planned, regex support for PATTERN
  # -R --recursive     planned, recursive rename? - maybe a baaaaad idea
    block_given? ? yield : {}
  end
  
end


class Filelist
  include Output
  
  def initialize()
  debug("Initializing the Filelist Object.")

    @dir = `pwd`.chomp + "/"
    @orig_list_array = Array.new
    @filecount = 0

    #check for existance of dir - abort if not
    if @dir == nil
      loud('Script failed. Could not automagically retrive current working directory.')
      exit
    end
    
    #create an array of all the filenames - skip directories
    Dir.foreach(@dir) do |f|

      next if f == '.' or f == '..'
      @filecount += 1

      #switch for directory options
      case 1
      when $op.only_dirs
        next if ! File.directory?(f)
      when   $op.dirs
      else
       next if File.directory?(f)
      end

      @orig_list_array << f
    end #Dir

    #Check to see if list_array is empty. - if so abort.
    begin
      @orig_list_array.empty? ? a = 1/0 : {} #raise exception to abort program
    rescue
      puts "There are no files to rename. Batch is aborting.\n"
      a = 1/0 #raise exception to abort program
    ensure
    end

    @list_array = @orig_list_array
    @searchcount = @orig_list_array.length

  end #init

# method filters the filelist array based upon the PATTERN and the options.
  def pattern
  Output::debug("pattern")

  # Error check - abort if no pattern!
  if $pattern == nil
    puts "You must supply a PATTERN or use the -a/--all option."
    print_usage{exit}
  end

    positive_array = Array.new
    negative_array = Array.new
    
      @orig_list_array.each do |a|
        if ($pattern_re).match(a)
          positive_array << a
        else
          negative_array << a
        end
      end #@list_array.each

    #Deal with inversion pattern here:
    if $op.invert == 1
      @list_array = negative_array
    else
      @list_array = positive_array
    end

  end #pattern

# method creates a hash from the array of filenames.  The keys are the original filenames, and the values will be populated by the replacement filenames, based upon which option is selected.
  def create_hash
    Output::debug("create_hash")
    
    #create hash from array
    @list_hash = Hash[ *@list_array.collect { |v| [ v, v ] }.flatten ]
  end

# method to change filesnames to upper-case
  def upcase
    Output::debug("upcase")

    create_hash
    
    up_hash = Hash.new

    @list_hash.each_key do |key|
      up_hash[key]=key.to_s.upcase
    end

    loud("Changing file names to Uppercase.")

    @list_hash.merge!(up_hash)
  end #upcase

# method to change filenames to lower-case
  def downcase
  Output::debug("downcase")

    create_hash

    down_hash = Hash.new

    @list_hash.each_key do |key|
      down_hash[key]=key.to_s.downcase
    end

    loud("Changing file names to Lowercase.")

    @list_hash.merge!(down_hash)
  end #downcase

# method that trims specified number of characters from the filenames.
  def trim
 Output::debug("trim")

    create_hash
    sub_hash = Hash.new

    if $op.trim == 0
      then
      loud("Trimming 0 characters does you no good!")
      print_usage{exit}
      
    #negative trim number
    elsif $op.trim <= 0
      @list_hash.each_key do |key|

          #make sure trim isn't too big
          if (-1 * $op.trim) < key.length
          sub_hash[key] = key.slice(($op.trim * -1)..key.length)

          end
        end        

    #positive trim number
    elsif $op.trim >= 0
      @list_hash.each_key do |key|
    
        #make sure trim isn't too big
        if $op.trim < key.length
          sub_hash[key] = key.slice(0..(key.length - $op.trim - 1))

        end #if
      end #each
    end #if

    @list_hash = sub_hash
  
  end #trim

# method that substitutes via gsub
  def substitute
  Output::debug("substitute")
  
    create_hash

    #error checking for errant options
    # cannot use -all option with sub.
    # cannot use -invert option with sub.

    case 1
    when $op.all
      loud('Ignoring the all option while performing a PATTERN substitution.')
    when $op.invert
      loud('Script aborted, you cannot apply a PATTERN substitution with the invert option.')
      exit
    end

    #populate @list_hash values with gsubbed keys
    sub_hash = Hash.new

    @list_hash.each_key do |key,value|
        sub_hash[key] = key.gsub($pattern_re,$replacement)
    end #each.key

    @list_hash.merge!(sub_hash)

  end #substitute

# method to perform append and prepend operations.
  def xx_pend
  debug("xx_pend")

    create_hash

    #populate @list_hash values with gsubbed keys
    sub_hash = Hash.new

    @list_hash.each_key do |key,value|
      $op.append == 1 ? sub_hash[key] = key + $replacement : {}
      $op.prepend == 1 ? sub_hash[key] = $replacement + key : {}
    end #each.key

    @list_hash.merge!(sub_hash)

  end #xx_pend

# method that renames the files.
  def rename_action
    debug("rename_action")
    @renamecount = 0
    @clobbercount = 0

    #get rid of empty values in the hash.
    @list_hash.delete_if { |key, value| value == '' }

      @list_hash.each_pair do |key, value|
  
        #check for duplicate key/value, & files - prevent clobbering
        if key != value and not @orig_list_array.include?(value)
          
          #rename clobber-free
          File.rename(key, value)
          @renamecount += 1
          verbose("#{key}  >>>  #{value}\n")

        else

          if $op.force != 1
            #announce clobbering
            verbose("#{key} will clobber #{value}; rename aborted.\n")

          else
            
            File.rename(key, value)
            @clobbercount += 1
            @renamecount += 1
            verbose("#{key}  >>>  #{value}\n")
          end #if $opt.force

        end #if anti-clobber
      end #@list_hash.each


      if $op.force == 1 
        loud("#{@renamecount} renames | #{@clobbercount} clobbered | #{@searchcount} considered | #{@filecount} objects.")
      else
        loud("#{@renamecount} renames | #{@searchcount} considered | #{@filecount} objects.")
      end

  end #rename_action

  # method to test give option for given value and print given text. Will execute code given in block.
  def option_check(var, tf, text)
      if var == tf
        puts text
      end

      block_given? ? yield : {}
  end
  
end #filelist


# method that contains the switching logic for the program.
def batch_rename()
  include Output
  debug("DEBUG MODE ON")
  debug("batch_rename()")

if $op.prepend == 1 or $op.append == 1
  then

  if ARGV[1] && ARGV[0] != nil
      $pattern = ARGV[0]
      $replacement = ARGV[1]
    elsif ARGV[0] != nil
      $replacement = ARGV[0]
    end

  else
  $pattern = ARGV[0]
  $replacement = ARGV[1]
  $replacement ||= ''
end

# set the switch for the Ignore Case option
$op.ignore_case != 1 ? $pattern_re = "/#{$pattern}/".to_regexp : $pattern_re = "/#{$pattern}/i".to_regexp


debug("PATTERN: #{$pattern}")
debug("REPLACEMENT: #{$replacement}")

  case 1
  when $op.help
    print_help{exit}
  when $op.version
    print_version{exit}
  end

  bob = Filelist.new


  $op.all == 1 ? next : bob.pattern

  case 1
  when $op.upcase
    bob.upcase
  when $op.downcase
    bob.downcase
  when $op.trimt
    bob.trim
  when $op.append
    bob.xx_pend
  when $op.prepend
    bob.xx_pend
  else
    $pattern == nil ? print_usage{exit} : bob.substitute
  end

  bob.rename_action

end #batch_rename()

if __FILE__ == $0
  batch_rename()
end