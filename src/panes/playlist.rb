#!/usr/bin/ruby

require 'Qt4'
require 'xmmsclient/async'

require 'panes/base.rb'
require 'models/playlistmodel.rb'
require 'views/mediaitemdelegate.rb'


# display a playlist, allow filtering and edition
class Playlist < Pane

  slots 'activate(const QModelIndex &)'

  def initialize(xc, cache)
    super

    @playlist = Qt::ListView.new
    @items = PlaylistModel.new(@xc, @cache)
    @deleg = MediaDelegate.new(@playlist)
    @playlist.setModel(@items)
    @playlist.setItemDelegate(@deleg)
    @playlist.setSelectionMode(Qt::AbstractItemView::ExtendedSelection)
    @playlist.setAlternatingRowColors(true)

    connect(@playlist, SIGNAL('activated(const QModelIndex &)'),
            self, SLOT('activate(const QModelIndex &)'))

    @cache.init_playlist_entries
    @cache.init_playlist_position
    @cache.init_mediainfos
  end

  def widget
    return @playlist
  end

  def run(arguments, register_opts = nil)
    # FIXME: filter/reset should reread position
    if arguments.nil?
      @items.clear_filter
    else
      coll = Xmms::Collection.parse(arguments)
      @items.filter(coll)
    end
  end

  def activate(item)
    @xc.playlist_set_next(item.row)
    @xc.playback_tickle
    @xc.playback_start unless @cache.playback_status == Xmms::Client::PLAY
  end
end
