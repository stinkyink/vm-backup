class VirtualMachine
  include Helpers

  attr_reader :uuid

  def self.all
    `#{VBOX_MANAGE} list vms`.split("\n").map {|line|
      matches = /{(.*)}/.match(line)
      if matches.nil?
        fail "Unable to parse VM entry: #{line}"
      end
      VirtualMachine.new(matches[1])
    }
  end

  def self.find(arg)
    [*arg].map {|vm_name|
      begin
        self.new(vm_name)
      rescue ProcessingError => e
        STDERR.puts %(WARNING: Unable to find VM "#{vm_name}": #{e.message})
        nil
      end
    }.compact
  end

  def initialize(vm_name)
    get_vminfo(vm_name)
    @uuid = vminfo['UUID']
  rescue ProcessingError => e
    fail "Unable to initialize: #{e.message}"
  end

  def to_s
    "#{name} {#{@uuid}}"
  end

  def name
    vminfo['name'] || fail("No Name found")
  end

  def config_file
    vminfo['CfgFile'] || fail("No config file found")
  end

  def hard_disks
    hdds = Array.new
    vminfo.each_pair do |key, value|
      if not key.index('ImageUUID').nil?
        hdd = VirtualHardDisk.new(value)
        hdds << hdd  unless hdd.is_dvd?
      end
    end
    hdds
  end

  def hard_disks_and_ancestors
    self.hard_disks.map {|x| [x, *x.ancestors] }.flatten
  end

  def state
    vminfo['VMState']
  end

  def start!
    quiet = "> /dev/null"  if $options.quiet
    cmd = "#{VBOX_MANAGE} startvm #{@uuid} --type headless #{quiet}"
    pid = Process.spawn(cmd)
    Process.wait(pid)
    if $?.exitstatus != 0
      fail "Unable to resume"
    end
  end

  def save!
    quiet = "2> /dev/null"  if $options.quiet
    cmd = "#{VBOX_MANAGE} controlvm #{@uuid} savestate #{quiet}"
    pid = Process.spawn(cmd)
    Process.wait(pid)
    if $?.exitstatus != 0
      fail "Unable to pause"
    end
  end

  private

  attr_accessor :vminfo

  def get_vminfo(vm_name)
    output = `#{VBOX_MANAGE} showvminfo --machinereadable "#{vm_name}"`
    if $?.exitstatus != 0
      fail 'Unable to retrieve info for VM.'
    end
    @vminfo =
      output.split("\n").each_with_object(Hash.new) do |line, acc|
        split = line.index('=')
        key = line[0..(split - 1)]
        value = line[(split + 1)..-1]
        key, value = [key, value].map {|x|
          x.start_with?('"') ? x[1..-2] : x
        }
        acc[key] = value
      end
  end
end
