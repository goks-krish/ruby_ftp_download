require 'net/ftp'
require 'zip'
require 'fileutils'
require_relative 'ftools'

def downloadFromFTP(destpath)
  
  transferred = 0
  last = 101;
  
  ftp = Net::FTP.new
  ftp.connect("ftp.epnet.com",21)
  ftp.login("medhand","viB5bYkE")
  ftp.chdir("/")
  ftp.passive = true
  files = ftp.nlst('*.zip')
  src = files.sort_by { |filename| ftp.mtime(filename) }.last
  filesize = ftp.size(src)
  dest=File.join(destpath,src);
  puts "Downloading File: #{src} of size: #{filesize} to #{dest}\n"
  
  ftp.getbinaryfile(src,dest,1024) do |data|
        transferred += data.size
        percent = ((transferred.to_f/filesize.to_f)*100).to_i
        finished = ((transferred.to_f/filesize.to_f)*30).to_i
        not_finished = 30 - finished
        if(last!=percent)
          print "\r Downloading  #{"%3i" % percent}%"
        end  
        last = percent
  end
  ftp.close()
  puts "\n Download Complete"
  return dest
end

def unzipXML(srcZip,workDir)

  puts srcZip+" extraction to "+workDir
  Zip::ZipFile.open(srcZip) { |zip_file|
      zip_file.each { |f|
      f_path=File.join(workDir , f.name)
      FileUtils.mkdir_p(File.dirname(f_path))
      zip_file.extract(f, f_path)
    }
   }
end

def mergeDownloadedFiles(src,dest)
  #src is the new files from download & dest is the src/xml/xml
  srcDir=src + "xml/";
  log = "Merging of downloaded files from: " + srcDir + " to src Folder:"+dest
  changedFiles = ""
  newFiles = ""
  noChangeFiles = ""
  deletedFiles = ""
  
  #Check for new/updated files
  Dir[srcDir+"*.xml"].each do |file_name|
    dest_file=File.join(dest , File.basename(file_name))
    if !File.exists?(dest_file)
      FileUtils.cp(file_name,dest_file);
      newFiles = newFiles + File.basename(file_name) + "\n"
    else
      if !File.compare(file_name, dest_file)
        FileUtils.cp(file_name,dest_file);
        changedFiles = changedFiles + File.basename(file_name) + "\n"
      else
        noChangeFiles = noChangeFiles + File.basename(file_name) + "\n"
      end
    end
  end
  
  #Check for deleted files
  Dir[dest+"*.xml"].each do |file_name|
    src_file = File.join(srcDir , File.basename(file_name))
    if !File.exists?(src_file)  
      FileUtils.rm(file_name)
      deletedFiles = deletedFiles + File.basename(file_name) + "\n"
    end
  end
  
  log = log + "\n Following are new Files\n" + newFiles
  log = log + "\n Following are Changed/Updated Files\n" + changedFiles
  log = log + "\n Following Files have not changed \n" + noChangeFiles
  log = log + "\n Following Files have been deleted \n" + deletedFiles
  
  begin
    file = File.open(src+"/Merge_Log.log", "w")
    file.write(log) 
  rescue IOError => e
    #some error occur, dir not writable etc.
  ensure
    file.close unless file.nil?
  end
end

#START Execution
destpath=ARGV[0]
if not ARGV[0]
  destpath=Dir.pwd+"/"
end

tarPath=ARGV[1]
if not ARGV[1]
  tarPath=Dir.pwd+"/xml"
end

ts = Time.now.strftime("%m%d%y%I%M%S%p") 
workDir = File.join(destpath,ts)
Dir.mkdir(workDir)
#1. Download File from FTP
srcZip = downloadFromFTP(workDir)

#2. Unzip downloaded File
unzipXML(srcZip,workDir)

#3. Merge downloaded xml file to master folder
mergeDownloadedFiles(workDir,tarPath)