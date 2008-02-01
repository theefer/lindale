#!/usr/bin/ruby

require 'Qt4'
require 'xmmsclient/async'

require './xmmsclient-qt4'

# FIXME: uh oh!
# GC.disable

# TODO:
# - keep playlist up-to-date wrt updates (complete cache, signals)
# - use columns to separate fields
# - type in playlist to filter playlist entries (custom search)
# - isolate commands/panes in classes



# FIXME: Could this proxy be merged into MediaItemModel?
class Cache < Qt::Object

  signals 'entryUpdated(int)'
  signals 'updatePos(int, int)'
  signals 'updateStatus(int, int)'
  signals 'playlistChanged(int, int, int)'

  attr_reader :currstatus

  def initialize(conn)
    super()

    @xc = conn
    @playlist = Array.new
    @mediainfos = Hash.new

    @xc.playlist.entries do |list|
      list.value.each {|id| playlistAppend(id)}
    end

    @xc.playlist.current_pos.notifier(&method(:listenPos))
    @xc.broadcast_playlist_current_pos.notifier(&method(:listenPos))

    @xc.playback_status.notifier(&method(:listenStatus))
    @xc.broadcast_playback_status.notifier(&method(:listenStatus))

    @currpos = -1
    @currstatus = -1

    self
  end

  def playlistAppend(id)
    @playlist.push(id)
    # FIXME: need action type constants!
    emit playlistChanged(0, id, @playlist.size - 1)
  end

  def getInfos(id)
    return @mediainfos[id] if @mediainfos.key?(id)

    @mediainfos[id] = nil
    @xc.medialib_get_info(id) do |dict|
      @mediainfos[id] = dict.value
      emit entryUpdated(id)
    end

    return nil
  end

  def listenPos(pos)
    emit updatePos(@currpos, pos.value)
    @currpos = pos.value
  end

  def listenStatus(status)
    emit updateStatus(@currstatus, status.value)
    @currstatus = status.value
  end    
end



class MediaItemModel < Qt::StandardItemModel

  MEDIA_ID_ROLE   = Qt::UserRole + 0
  READY_ROLE      = Qt::UserRole + 1
  CURRENT_ROLE    = Qt::UserRole + 2

  slots 'updateMedia(int)', 'updateCurrPos(int, int)', 'updatePlaylist(int, int, int)'

  def initialize(parent, conn, cache)
    super(parent)

    @xc = conn
    @cache = cache
    @filter_ids = Array.new

    connect(@cache, SIGNAL('entryUpdated(int)'), self, SLOT('updateMedia(int)'))
    connect(@cache, SIGNAL('updatePos(int, int)'), self, SLOT('updateCurrPos(int, int)'))
    connect(@cache, SIGNAL('playlistChanged(int, int, int)'), self, SLOT('updatePlaylist(int, int, int)'))

#    setHorizontalHeaderLabels(["", "Title"])

    self
  end

  def filter(pattern)
    coll = Xmms::Collection.parse(pattern)
    @xc.coll_query_ids(coll) do |res|
      @filter_ids.clear
      @filter_ids = res.value
    end
  end

  def updatePlaylist(type, id, pos)
    # FIXME: check type for type!
    appendRow(MediaItem.new(id))
  end

  def updateCurrPos(oldpos, pos)
    item(oldpos).setData(Qt::Variant.new(false), CURRENT_ROLE) if hasIndex(oldpos, 0)
    item(pos).setData(Qt::Variant.new(true), CURRENT_ROLE) if hasIndex(pos, 0)
  end

  def updateMedia(id)
    metadata = @cache.getInfos(id)
    max = rowCount
    for i in 0...max
      it = item(i)
      if it.mid == id
        text = ""
        text += metadata[:artist] + " - " unless metadata[:artist].nil?
        text += metadata[:title] unless metadata[:title].nil?
        text = metadata[:url] if text.empty?
        it.setData(Qt::Variant.new(text), Qt::DisplayRole)
        it.setData(Qt::Variant.new(true), READY_ROLE)
      end
    end
  end

  def data(idx, role = Qt::DisplayRole)
    unless super(idx, READY_ROLE).toBool
      id = super(idx, MEDIA_ID_ROLE).toInt
      @cache.getInfos(id)
    end

    super(idx, role)
  end
end


class PlayListView < Qt::ListView
  # FIXME: kinda ugly, no?
  def initialize(*args)
    super(*args)
    @search = ""
  end

  def keyPressEvent(e)
    # FIXME: Ctrl+Up/Down to move selection
    if e.key == Qt::Key_Delete
      # reorder to remove lowest first!
      selectionModel.selectedRows.map {|x| x.row}.sort.reverse.each do |idx|
        # FIXME: hey, update xmms2 too, not just the model!
        model.removeRow(idx)
      end
      # FIXME: when to clear @search? lose focus, click, etc.
      @search = ""
    elsif e.key == Qt::Key_Return
      # FIXME: ENTER (resp. ESC) to leave search and keep (resp. cancel) selection
      @search = ""
    elsif e.key == Qt::Key_Escape
      selectionModel.clearSelection
      @search = ""
    elsif !e.text.nil? and !e.text.empty?
      # FIXME: weird stuff with C-d, Backspace, etc
      # FIXME: display search string somewhere
      if e.key == Qt::Key_Backspace
        @search.slice!(-1) unless @search == ""
      else
        @search << e.text
      end
      puts @search
      selectionModel.clearSelection
      if @search.size > 1
        indices = model.match(currentIndex, Qt::DisplayRole,
                              Qt::Variant.new(@search), -1,
                              (Qt::MatchContains | Qt::MatchWrap))
        indices.each do |idx|
          selectionModel.select(idx, Qt::ItemSelectionModel::Select)
        end
      end
    else
      super(e)
    end
  end
end

class MediaItem < Qt::StandardItem
  def initialize(id)
    super()
    setData(Qt::Variant.new(id), MediaItemModel::MEDIA_ID_ROLE)
    setData(Qt::Variant.new(id), Qt::DisplayRole)
    setData(Qt::Variant.new(false), MediaItemModel::READY_ROLE)
    setEditable(false)

    self
  end

  def mid()
    return data(MediaItemModel::MEDIA_ID_ROLE).toUInt
  end

  def id()
    return mid
  end
end


class MediaDelegate < Qt::ItemDelegate
  def initialize(parent)
    super(parent)
  end

  def paint(painter, option, index)
    # FIXME: Do something sexy later on instead
    curr = index.model.data(index, MediaItemModel::CURRENT_ROLE).toBool
    text = index.model.data(index, Qt::DisplayRole).toString

    painter.save
    font = option.font
    font.setBold(true) if curr
    painter.setFont(font)

    if parent.selectionModel.isSelected(index)
      painter.fillRect(option.rect, option.palette.highlight)
      painter.setPen(Qt::Color.new(Qt::white))
    end
    painter.drawText(option.rect, Qt::AlignLeft, text)
    painter.restore
#    super(painter, option, index)
  end
end


class MyWidget < Qt::Widget

  slots 'run()', 'tab()', 'switchFocus()', 'activate(const QModelIndex &)'

  def initialize(xclient)
    super()

    @xc = xclient
    @cache = Cache.new(@xc)

    @cmd = Qt::LineEdit.new

#    @playlist = Qt::TableView.new
    @playlist = PlayListView.new
    items = MediaItemModel.new(@playlist, @xc, @cache)
    deleg = MediaDelegate.new(@playlist)
    @playlist.setModel(items)
    @playlist.setItemDelegate(deleg)
    @playlist.setSelectionMode(Qt::AbstractItemView::ExtendedSelection)
    @playlist.setAlternatingRowColors(true)

#    @playlist.showGrid = false
#    @playlist.verticalHeader.hide

    # set background
#    palette = @playlist.palette
#    palette.setBrush(Qt::Palette::Window,
#                     Qt::Brush.new(Qt::Pixmap.new("Logo-white-128.png")))
#    @playlist.setPalette(palette)
#    @playlist.setAutoFillBackground(true)

    @mlib = Qt::ListView.new
    #    @mlib.setModel(items)

    shortcut_tab = Qt::Shortcut.new(Qt::KeySequence.new("Tab"), self)
    shortcut_ctrltab = Qt::Shortcut.new(Qt::KeySequence.new("Ctrl+Tab"), self)
    shortcut_left = Qt::Shortcut.new(Qt::KeySequence.new("Ctrl+Left"), self)
    shortcut_right = Qt::Shortcut.new(Qt::KeySequence.new("Ctrl+Right"), self)

    connect(@cmd, SIGNAL('returnPressed()'), self, SLOT('run()'))

    connect(shortcut_tab, SIGNAL('activated()'), self, SLOT('switchFocus()'))
    connect(shortcut_ctrltab, SIGNAL('activated()'), self, SLOT('tab()'))
    connect(shortcut_left, SIGNAL('activated()'), self, SLOT('tab()'))
    connect(shortcut_right, SIGNAL('activated()'), self, SLOT('tab()'))

    connect(@playlist, SIGNAL('activated(const QModelIndex &)'), self,
            SLOT('activate(const QModelIndex &)'))

    @stack = Qt::StackedWidget.new
    @stack.addWidget(@playlist)
    @stack.addWidget(@mlib)

    layout = Qt::VBoxLayout.new
    layout.addWidget(@cmd)
    layout.addWidget(@stack)
    setLayout(layout)
  end

  def tab()
    newIndex = (@stack.currentIndex + 1) % @stack.count
    @stack.setCurrentIndex(newIndex)
  end

  def switchFocus()
    if @cmd.hasFocus
      @stack.currentWidget.setFocus(Qt::TabFocusReason)
    else
      @cmd.setFocus(Qt::TabFocusReason)
    end
  end

  def play()
    @xc.playback_start
  end

  def pause()
    @xc.playback_pause
  end

  def run()
    puts "ENTER: " + @cmd.text
    case @cmd.text
    when "play"
      play
    when "pause"
      pause
    when "egg"
      tab
    when /^list(\s.+)?$/
      @playlist.model.filter($1.strip) unless $1.nil?
      @stack.setCurrentWidget(@playlist)
    when /^search(\s.+)?$/
      # FIXME: search
      @stack.setCurrentWidget(@mlib)
    end
  end

  def activate(item)
    @xc.playlist_set_next(item.row)
    @xc.playback_tickle
    @xc.playback_start unless @cache.currstatus == Xmms::Client::PLAY
  end
end


app = Qt::Application.new(ARGV)

xc = Xmms::Client::Async.new("lindale")
xc.connect(ENV["XMMS_PATH"])
xc.add_to_qt4_mainloop

widget = MyWidget.new(xc)

mainwin = Qt::MainWindow.new
mainwin.setCentralWidget(widget)
mainwin.setWindowTitle("lindalë")
sb = mainwin.statusBar
mainwin.show

app.exec()
