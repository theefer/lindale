#!/usr/bin/ruby

require 'Qt4'


class MediaDelegate < Qt::ItemDelegate
  def initialize(parent)
    super(parent)
  end

  def paint(painter, option, index)
    # FIXME: Do something sexy later on instead
    curr = index.model.data(index, PlaylistModel::CURRENT_ROLE).toBool
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
