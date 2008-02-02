#!/usr/bin/ruby

require 'Qt4'
require 'xmmsclient/async'

require 'panes/base.rb'


# sends simple commands to the xmms2 server, without any interface
class Control < Pane

  signals 'message(const QString&)', 'warning(const QString&)', 'error(const QString&)'

  def initialize(xc, cache)
    super

    # init cache
    @cache.init_playback_status
  end

  def run(arguments, register_opts = nil)
    # FIXME: use arguments?

    case register_opts
    when :play
      @xc.playback_start
      emit message("Playback started.")

    when :pause
      @xc.playback_pause
      emit message("Playback paused.")

    when :stop
      @xc.playback_stop
      emit message("Playback stopped.")

    when :toggleplay
      if @cache.playback_status == Xmms::Client::PLAY
        @xc.playback_pause
        emit message("Playback paused.")
      else
        @xc.playback_start
        emit message("Playback started.")
      end

    else
      # FIXME: error?
    end
  end
end

