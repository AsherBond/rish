# This file extends the Kernel's require function and adds the 
# AutoReload module which allows to reload files once they have changed
# on the disk.
#
# Basically, you just require your files as usual, and if you want to update
# the files, either call AutoReload.reload(file) or AutoReload.reload_all.
#
# Written by Mikio L. Braun, March 16, 2008
require 'pp'
require 'set'

# This module tracks loaded files and their timestamps and allows to reload
# files which have changed automatically by calling reload.
module Rish
  module Autoreload
    # stores the normalized filenames and their File.mtime timestamps
    @timestamps = Hash.new
    @notfound = Set.new
    @verbose = false
    @watched_dirs = []
    
    def self.verbose=(flag)
      @verbose = flag
    end
    
    # find the full path to a file
    def self.locate(file)
      return nil if @notfound.include? file
      $:.each do |dir|
        fullpath = File.join(dir, file)
        if File.exists? fullpath
          return fullpath
        elsif File.exists?(fullpath + '.rb')
          return fullpath + '.rb'
        elsif File.exists?(fullpath + '.so')
          return fullpath + '.so'
        end
      end
      # puts "[JML::AutoReload] File #{file} not found!"
      @notfound.add file
      return nil
    end
    
    # store the time stamp of a file
    def self.timestamp(file)
      path = locate(file)
      if path
        file = normalize(path, file)
        @timestamps[file] = File.mtime(path)
      end
    end
    
    # put the extension on a filename
    def self.normalize(path, file)
      if File.extname(file) == ""
        return file + File.extname(path)
      else
        return file
      end
    end
    
    # show all stored files and their timestamp
    def self.dump
      pp @timestamps
    end
    
    # reload a file
    def self.reload(file, force=false)
      path = locate(file)
      file = normalize(path, file)
      
      if force or (path and File.mtime(path) > @timestamps[file])
        puts "[JML::AutoReload] reloading #{file}" if @verbose
        
        # delete file from list of loaded modules, and reload
        $".delete file
        require file
        return true
      else
        return false
      end
    end
    
    # reload all files which were required
    def self.reload_all(force=false)
      @timestamps.each_key do |file|
        self.reload(file, force)
      end
      check_directories
    end
    
    # add directories to be watched
    def self.watch_directory(dir)
      @watched_dirs << dir
    end
    
    def self.check_directories
      @watched_dirs.each do |dir|
        Dir.glob("#{dir}/**/*.rb").each do |fn| 
          if @timestamps.include? fn
            reload(fn)
          else
            require(fn)
          end
        end
      end
    end
  end
end

# Overwrite 'require' to register the time stamps instead.
module Kernel # :nodoc:
  alias old_require require
  
  def require(file)
    Rish::Autoreload.timestamp(file)
    old_require(file)
  end
end
