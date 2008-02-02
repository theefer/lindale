#!/usr/bin/ruby

require 'Qt4'


class MediaItem < Qt::StandardItem

  def initialize(id)
    super
    setData(Qt::Variant.new(id), MediaItemModel::MEDIA_ID_ROLE)
    setData(Qt::Variant.new(id), Qt::DisplayRole)
    setData(Qt::Variant.new(false), MediaItemModel::READY_ROLE)
    setEditable(false)
  end

  def set_metadata(metadata)
    text = ""
    text += metadata[:artist] + " - " unless metadata[:artist].nil?
    text += metadata[:title] unless metadata[:title].nil?
    text = metadata[:url] if text.empty?
    setData(Qt::Variant.new(text), Qt::DisplayRole)
    setData(Qt::Variant.new(true), MediaItemModel::READY_ROLE)
  end

  def mid
    return data(MediaItemModel::MEDIA_ID_ROLE).toUInt
  end

  def id
    return mid
  end
end


class MediaItemModel < Qt::StandardItemModel

  MEDIA_ID_ROLE   = Qt::UserRole + 0
  READY_ROLE      = Qt::UserRole + 1
  USER_ROLE       = Qt::UserRole + 2

  slots 'update_metadata(int)',
        'append_id(int)',
        'insert_id(int, int)',
        'remove_at(int)'


  def initialize(xc, cache)
    super()

    @cache = cache
    @xc = xc
    @pending = Hash.new

    connect(@cache, SIGNAL('metadata_received(int)'), self, SLOT('update_metadata(int)'))
  end

  def append_id(id)
    item = MediaItem.new(id)
    appendRow(item)
    set_metadata(id, item, rowCount - 1)
  end

  def insert_id(pos, id)
    item = MediaItem.new(id)
    insertRow(pos, item)
    set_metadata(id, item, pos)
  end

  def remove_at(pos)
    takeRow(pos)
  end

  def set_metadata(id, item, pos)
    if @cache.has_mediainfos?(id)
      item.set_metadata(@cache.fetch_mediainfos(id))
    else
      @pending[id] = Array.new unless @pending.key?(id)
      @pending[id].push(pos)
    end
  end

  def update_metadata(id)
    metadata = @cache.fetch_mediainfos(id)
    # FIXME: hackish, errors!
    return unless @pending.key?(id)
    while pos = @pending[id].shift
      item(pos).set_metadata(metadata) if pos < rowCount
    end
  end

  def data(idx, role = Qt::DisplayRole)
    unless super(idx, READY_ROLE).toBool
      id = super(idx, MEDIA_ID_ROLE).toInt
      @cache.fetch_mediainfos(id)
    end

    super(idx, role)
  end
end
