#!/usr/bin/ruby

require 'Qt4'
require 'xmmsclient/async'


class Xmms2Cache < Qt::Object

  signals 'metadata_received(int)', 'status_updated(int, int)', 'position_updated(int, int)',
          'playlist_refreshed()', 'playlist_loaded(const QString&, const QString&)',
          'playlist_entry_inserted(int, int)',
          'playlist_entry_removed(int)'

  attr_reader :playback_status, :playlist_position, :playlist_entries,
              :playlist_active

  def initialize(conn)
    super()

    @xc = conn
  end

  def init_playback_status()
    unless defined?(@playback_status)
      @playback_status = nil
      @xc.playback_status.notifier(&method(:listen_status))
      @xc.broadcast_playback_status.notifier(&method(:listen_status))
    end
  end

  def init_playlist_position()
    unless defined?(@playlist_position)
      @playlist_position = nil
      @xc.playlist.current_pos.notifier(&method(:listen_position))
      @xc.broadcast_playlist_current_pos.notifier(&method(:listen_position))
    end
  end

  def init_playlist_active()
    unless defined?(@playlist_active)
      @playlist_active = nil
      @xc.playlist_current_active.notifier(&method(:listen_playlist_active))
      @xc.broadcast_playlist_loaded.notifier(&method(:listen_playlist_active))
    end
  end

  def init_playlist_entries()
    unless defined?(@playlist_entries)
      # we need to track the active playlist
      init_playlist_active

      @playlist_entries = nil
      @xc.playlist.entries.notifier(&method(:listen_playlist_entries))
      @xc.broadcast_playlist_changed.notifier(&method(:listen_playlist_changes))
    end
  end

  def init_mediainfos()
    unless defined?(@mediainfos)
      @mediainfos = Hash.new
      @xc.broadcast_medialib_entry_changed.notifier(&method(:listen_mlib_entry))
    end
  end

  def has_mediainfos?(id)
    return @mediainfos.key?(id)
  end

  def fetch_mediainfos(id)
    if has_mediainfos?(id)
      return @mediainfos[id]
    else
      update_mediainfos(id)
      return nil
    end
  end

  private
  def listen_status(status)
    old_status = if @playback_status.nil? then -1 else @playback_status end
    @playback_status = status.value
    emit status_updated(old_status, @playback_status)
  end

  def listen_position(pos)
    old_pos = if @playlist_position.nil? then -1 else @playlist_position end
    @playlist_position = pos.value
    emit position_updated(old_pos, @playlist_position)
  end

  def listen_playlist_active(name)
    old_name = if @playlist_active.nil? then nil else @playlist_active end
    @playlist_active = name.value
    emit playlist_loaded(old_name, @playlist_active)
  end

  def listen_playlist_entries(entries)
    @playlist_entries = entries.value
    emit playlist_refreshed()
  end

  def listen_playlist_changes(res)
    desc = res.value

    return if desc[:name] != @playlist_active

    case desc[:type]
    when Xmms::Playlist::ADD
      @playlist_entries.push(desc[:id])
      emit playlist_entry_inserted(@playlist_entries.size - 1, desc[:id])

    when Xmms::Playlist::INSERT
      @playlist_entries.insert(desc[:position], desc[:id])
      emit playlist_entry_inserted(desc[:position], desc[:id])

    when Xmms::Playlist::REMOVE
      @playlist_entries.delete_at(desc[:position])
      emit playlist_entry_removed(desc[:position])

    when Xmms::Playlist::MOVE
      @playlist_entries.delete_at(desc[:position])
      @playlist_entries.insert(desc[:newposition], desc[:id])
      emit playlist_entry_removed(desc[:position])
      emit playlist_entry_inserted(desc[:newposition], desc[:id])
      # FIXME: check that pos is correct

    when Xmms::Playlist::CLEAR
      @playlist_entries.clear
      emit playlist_refreshed()

    when Xmms::Playlist::UPDATE, Xmms::Playlist::SORT, Xmms::Playlist::SHUFFLE
      @xc.playlist.entries.notifier(&method(:listen_playlist_entries))
    else
      # FIXME: some kind of error <:o)
    end
  end

  def listen_mlib_entry(res)
    update_mediainfos(res.value)
  end

  def update_mediainfos(id)
    @mediainfos[id] = nil
    @xc.medialib_get_info(id) do |dict|
      @mediainfos[id] = dict.value
      emit metadata_received(id)
    end
  end
end
