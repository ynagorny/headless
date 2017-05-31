require 'headless'

describe Headless::VideoRecorder do
  before do
    stub_environment
  end

  describe "instantiation" do
    context 'no ffmpeg installed' do
      before do
        Headless::CliUtil.stub(:application_exists?).and_return(false)
      end

      it "throws an error if ffmpeg is not installed" do
          lambda { Headless::VideoRecorder.new(99, "1024x768x32") }.should raise_error(Headless::Exception)
      end
    end

    context 'no unclutter installed' do
      before do
        Headless::CliUtil.stub(:application_exists?).with('ffmpeg').and_return(true)
        Headless::CliUtil.stub(:application_exists?).with('unclutter').and_return(false)
      end

      it "throws an error if unclutter is not installed" do
        lambda { Headless::VideoRecorder.new(99, "1024x768x32") }.should raise_error(Headless::Exception)
      end
    end
  end

  describe "#capture" do
    it "starts ffmpeg and unclutter" do
      Headless::CliUtil.stub(:path_to).with('ffmpeg').and_return('ffmpeg')
      Headless::CliUtil.should_receive(:fork_process).with(/ffmpeg -y -r 30 -g 600 -s 1024x768x32 -f x11grab -i :99 -vcodec qtrle/, "/tmp/.headless_ffmpeg_99.pid", '/dev/null')
      Headless::CliUtil.stub(:path_to).with('unclutter').and_return('unclutter')
      Headless::CliUtil.should_receive(:fork_process).with(/unclutter -display :99 -idle 0.01 -root/, '/tmp/.headless_unclutter_99.pid', '/dev/null')

      recorder = Headless::VideoRecorder.new(99, "1024x768x32")
      File.stub(:exists?).and_return(true)
      recorder.start_capture
    end

    it "starts ffmpeg with specified codec" do
      Headless::CliUtil.stub(:path_to).and_return('ffmpeg')
      Headless::CliUtil.should_receive(:fork_process).with(/ffmpeg -y -r 30 -g 600 -s 1024x768x32 -f x11grab -i :99 -vcodec libvpx/, "/tmp/.headless_ffmpeg_99.pid", '/dev/null')

      recorder = Headless::VideoRecorder.new(99, "1024x768x32", {:codec => 'libvpx'})
      File.stub(:exists?).and_return(true)
      recorder.start_capture
    end
  end

  context "stopping video recording" do
    let(:tmpfile) { '/tmp/ci.mov' }
    let(:filename) { '/tmp/test.mov' }
    let(:pidfile) { '/tmp/pid' }
    let(:unclutter_pidfile) { '/tmp/unclutter_pid' }

    subject do
      recorder = Headless::VideoRecorder.new(99, "1024x768x32", :pid_file_path => pidfile, :tmp_file_path => tmpfile, :unclutter_pid_file_path => unclutter_pidfile)
      File.stub(:exists?).and_return(true)
      recorder.start_capture
      recorder
    end

    describe "using #stop_and_save" do
      it "stops video recording and saves file" do
        Headless::CliUtil.should_receive(:kill_process).with(unclutter_pidfile)
        Headless::CliUtil.should_receive(:kill_process).with(pidfile, :wait => true)
        File.should_receive(:exists?).with(tmpfile).and_return(true)
        FileUtils.should_receive(:mv).with(tmpfile, filename)

        subject.stop_and_save(filename)
      end
    end

    describe "using #stop_and_discard" do
      it "stops video recording and deletes temporary file" do
        Headless::CliUtil.should_receive(:kill_process).with(unclutter_pidfile)
        Headless::CliUtil.should_receive(:kill_process).with(pidfile, :wait => true)
        FileUtils.should_receive(:rm).with(tmpfile)

        subject.stop_and_discard
      end
    end
  end

private

  def stub_environment
    Headless::CliUtil.stub(:application_exists?).and_return(true)
    Headless::CliUtil.stub(:fork_process).and_return(true)
  end
end
