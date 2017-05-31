require 'tempfile'
require 'retryable'

class Headless
  class VideoRecorder
    attr_accessor :pid_file_path, :tmp_file_path, :log_file_path

    def initialize(display, dimensions, options = {})
      @codec = options.fetch(:codec, "qtrle")
      @frame_rate = options.fetch(:frame_rate, 30)
      @provider = options.fetch(:provider, :libav)  # or :ffmpeg
      @extra = options.fetch(:extra, [])
      @extra = [ @extra ] unless @extra.kind_of? Array
      @hide_cursor = options.fetch(:hide_cursor, true)

      @display = display
      @dimensions = dimensions

      CliUtil.ensure_application_exists!('ffmpeg', 'Ffmpeg not found on your system. Install it with sudo apt-get install ffmpeg')
      CliUtil.ensure_application_exists!('unclutter', 'unclutter not found on your system. Install it with sudo apt-get install unclutter') if @hide_cursor

      @tmp_file_path = options.fetch(:tmp_file_path, "/tmp/.headless_ffmpeg_#{@display}.mov")
      @pid_file_path = options.fetch(:pid_file_path, "/tmp/.headless_ffmpeg_#{@display}.pid")
      @unclutter_pid_file_path = options.fetch(:unclutter_pid_file_path, "/tmp/.headless_unclutter_#{@display}.pid")
      @log_file_path = options.fetch(:log_file_path, "/dev/null")
      @unclutter_log_file_path = options.fetch(:unclutter_log_file_path, "/dev/null")
    end

    def capture_running?
      CliUtil.read_pid @pid_file_path
    end

    def start_capture
      if @provider == :libav
        group_of_pic_size_option = '-g 600'
        dimensions = @dimensions
      else
        group_of_pic_size_option = ''
        dimensions = @dimensions.match(/^(\d+x\d+)/)[0]
      end

      extra = @extra.join(' ')

      CliUtil.fork_process("#{CliUtil.path_to('unclutter')} -display :#{@display} -idle 0.01 -root", @unclutter_pid_file_path, @unclutter_log_file_path)
      CliUtil.fork_process("#{CliUtil.path_to('ffmpeg')} -y -r #{@frame_rate} #{group_of_pic_size_option} -s #{dimensions} -f x11grab -i :#{@display} -vcodec #{@codec} #{extra} #{@tmp_file_path}", @pid_file_path, @log_file_path)
      # give the file 10 seconds to create, then quietly give up
      Retryable.retryable(:tries => 100, :sleep => 0.1) do
        fail "File #{@tmp_file_path} is not created yet" unless File.exists?(@tmp_file_path)
      end rescue nil
      
      at_exit do
        exit_status = $!.status if $!.is_a?(SystemExit)
        stop_and_discard
        exit exit_status if exit_status
      end
    end

    def stop_and_save(path)
      stop
      if File.exists? @tmp_file_path
        begin
          FileUtils.mv(@tmp_file_path, path)
        rescue Errno::EINVAL
          nil
        end
      end
    end

    def stop_and_discard
      stop
      begin
        FileUtils.rm(@tmp_file_path)
      rescue Errno::ENOENT
        # that's ok if the file doesn't exist
      end
    end

    private

    def stop
      CliUtil.kill_process(@unclutter_pid_file_path)
      CliUtil.kill_process(@pid_file_path, :wait => true)
    end
  end
end
