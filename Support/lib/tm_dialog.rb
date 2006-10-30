class TMDialog
  TMDialog::DIALOG = ENV['TM_SUPPORT_PATH'] + '/bin/tm_dialog'
  require ENV['TM_SUPPORT_PATH'] + '/lib/escape'
  require ENV['TM_SUPPORT_PATH'] + '/lib/plist'

  def TMDialog.request_menu(items)
    plist = {
      'menuItems'  => items.map{ |s| 
        s==""? {'separator' => true} : {'title' => s} 
      }
    }.to_plist
    res = PropertyList::load(%x{ #{e_sh DIALOG} -up #{e_sh plist} })
    return nil unless res.has_key? 'selectedMenuItem'
    return res['selectedMenuItem']['title']
  end
end
