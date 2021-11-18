***
* Waka Time Plugin for VFP
***

lparameters lcApiKey,lcProxy,lcLogFile

if empty(evl(lcApiKey,''))
   wait window "Waka Time APIKEY required!" timeout 2
   return
endif

public oWakaTime as CWakaTime

* initialize Event-Hooks
oWakaTime = createobject('CWakaTime')
oWakaTime.cApiKey=lcApiKey
oWakaTime.cProxy=lcProxy
oWakaTime.cLogPath=lcLogFile
oWakaTime.Setup()

return

*-- Windows constants
#define WM_CREATE           0x0001
#define WM_DESTROY          0x0002
#define WM_ACTIVATE         0x0006
#define WM_SETFOCUS         0x0007
#define WM_SETTEXT          0x000C
#define WM_SHOWWINDOW       0x0018
#define WM_KEYUP            0x0101
#define WM_LBUTTONUP        0x0202
#define GWL_WNDPROC         (-4)
#define WS_BORDER           0x00800000
#DEFINE GA_PARENT           0x0001 

define class CWakaTime as Custom
   cVersion='1.0'
   
   cApiKey=''
   cProxy=''
   cLogPath=''
   
   nVfpWndProc=0
   nLastHWnd=0
   oWindows=.f.
   oBeats=.f.
   oSH=.null.
   
   procedure Setup
      
      this.Dbg('Init WakaTime '+this.cVersion)
      
      this.oSH=createobject("WSCRIPT.SHELL")
       
      this.oWindows = createobject('Collection')
      this.oBeats = createobject('Collection')
      
      * VFP Wndow
      this.nVfpWndProc = this.GetWindowLong(_Vfp.hWnd, GWL_WNDPROC)
      this.Dbg('VFP WndProc: '+alltrim(str(this.nVfpWndProc)))
      
      * Watch WM_CREATE globaly
      bindevent(0, WM_CREATE, this, "WMEventHandler")
      this.Dbg('Events bound')
   endproc
   
   procedure NewWindow
      lparameters lnHWnd as Integer
      local loWnd as CWindow, lcKey as string
      local loErr as Exception
      try
         this.Dbg('New window handle: '+alltrim(str(lnHWnd)))
         
         lcKey = transform(lnHWnd,'@0x')
         if !empty(this.oWindows.GetKey(lcKey))
            * Already known window
            exit
         endif
         
         * new window
         loWnd = createobject('CWindow')
         loWnd.nHWnd = lnHWnd
         loWnd.cTitle = this.GetWindowTitle(lnHWnd)
         this.Dbg('New Window: '+loWnd.cTitle)
         this.oWindows.Add(loWnd, lcKey)
         
         * Register events
         bindevent(lnHWnd, WM_DESTROY, this, 'WMEventHandler')
         bindevent(lnHWnd, WM_SETTEXT, this, 'WMEventHandler')
         bindevent(lnHWnd, WM_SETFOCUS, this, 'WMEventHandler')
         bindevent(lnHWnd, WM_KEYUP, this, 'WMEventHandler')
         bindevent(lnHWnd, WM_LBUTTONUP, this, 'WMEventHandler')
      catch to loErr
         this.Exc(loErr)
      endtry
   endproc
   
   
   ********************************************************************************
   *                                Event Handlers                                
   ******************************************************************************** 
   
   procedure WindowShow
      lparameters lnHWnd as integer
      local loErr as Exception
      try 
         if empty(lnHWnd)
            exit
         endif
         
         this.Dbg('WM_SHOWWINDOW '+alltrim(str(lnHWnd)))
         
         if !empty(This.oWindows.GetKey(transform(lnHWnd, "@0x")))
            * Check the window is still a child of _Screen.
            if _Screen.hWnd # this.GetAncestor(lnHWnd, GA_PARENT)
               * Remove Window
               This.WindowDestroy(lnHWnd)
            endif 
            exit                              
         endif
         
         * Check if window is known
         if !empty(this.oWindows.GetKey(transform(lnHWnd,'@0x')))
            exit
         endif
         
         if !this.IsIDEWindow(lnHWnd)
            * Not a window we're interested in
            unbindevents(lnHWnd, 0)
            exit
         endif
         
         * Add new window
         this.NewWindow(lnHWnd)
      catch to loErr
         this.Exc(loErr)
      endtry
   endproc
   
   procedure WindowDestroy 
      lparameters lnHWnd as integer 
      local loErr as Exception, lcKey as string, lcTitle as string
      try
         
         this.Dbg('WM_DESTROY '+alltrim(str(lnHWnd)))
         
         
         lcKey = transform(lnHWnd,'@0x')
         if empty(this.oWindows.GetKey(lcKey))
            * unkown window
            exit
         endif
         
         * Forget window
         this.oWindows.Remove(lcKey)
         
         * Release events
         unbindevents(lnHWnd, 0)
         
      catch to loErr
         this.Exc(loErr)
      endtry
   endproc
   
   procedure WindowSetFocus
      lparameters lnHWnd as Integer
      local loErr as Exception
      local loWnd as CWindow, lcKey as string
      try
      
         this.Dbg('WM_SETFOCUS '+alltrim(str(lnHWnd)))
         
         lcKey = transform(lnHWnd, '@x0')
         if empty(this.oWindows.GetKey(lcKey))
            * unkown window
            exit
         endif
         
         loWnd = this.oWindows.Item(lcKey)
         
         * Check for changed title
         this.CheckTitle(loWnd)
         
         * send focus heartbeat
         this.SendHeartbeat(.f., loWnd.nHWnd)
         
      catch to loErr
         this.Exc(loErr)
      endtry
   endproc
   
   procedure WindowSetText
      lparameters lnHWnd as Integer
      local loErr as Exception
      local loWnd as CWindow, lcKey as string
      try 
         if empty(lnHWnd)
            exit
         endif
         
         this.Dbg('WM_SETTEXT '+alltrim(str(lnHWnd)))
         
         * Sometimes WM_SETTEXT is fired before WM_SHOWWINDOW (on maximized windows)
         this.WindowShow(lnHWnd)
         
         lcKey = transform(lnHWnd, '@x0')
         if empty(this.oWindows.GetKey(lcKey))
            * unkown window
            exit
         endif
         
         if !empty(This.oWindows.GetKey(transform(lnHWnd, "@0x")))
            * Check the window is still a child of _Screen.
            if _Screen.hWnd # this.GetAncestor(lnHWnd, GA_PARENT)
               * Remove Window
               This.WindowDestroy(lnHWnd)
            endif 
            exit                              
         endif
         
         loWnd = this.oWindows.Item(lcKey)
         
         * Check for changed title
         this.CheckTitle(loWnd)
         
      catch to loErr
         this.Exc(loErr)
      endtry
   endproc
   
   procedure WindowInput
      lparameters lnHWnd as Integer
      local loErr as Exception
      local lcKey as string
      try 
         if empty(lnHWnd)
            exit
         endif
         
         this.Dbg('Input (WM_KEYUP/WM_LBUTTONUP) '+alltrim(str(lnHWnd)))
         
         lcKey = transform(lnHWnd, '@x0')
         if empty(this.oWindows.GetKey(lcKey))
            * unkown window
            exit
         endif
         
         loWnd = this.oWindows.Item(lcKey)
         
         * send input heartbeat
         this.SendHeartbeat(.f., loWnd.nHWnd)
         
      catch to loErr
         this.Exc(loErr)
      endtry
   endproc
   
   procedure CheckTitle
      lparameters loWnd as CWindow
      lcTitle = this.GetWindowTitle(loWnd.nHWnd)
      if !(lcTitle == loWnd.cTitle)
         this.Dbg('Window title changed. From: '+loWnd.cTitle+'  To: '+lcTitle)
         * Title changed
         if right(loWnd.cTitle,2) == ' *' and !(right(lcTitle,2) == ' *')
            * Was edited, now saved
            this.SendHeartbeat(.t., loWnd.nHWnd)
         endif
         loWnd.cTitle=lcTitle
      endif
   endproc
   
   procedure SendHeartbeat
      lparameters llWrite as boolean, lnHWnd as integer
      local loErr as Exception
      local lcTitle as string, lcPath as string, lcProj as string
      local lcParams as string, ltLastBeat as datetime, ltBeatTS as datetime
      local lcCli as string
      try
         * Get file name
         lcTitle = this.GetWindowTitle(lnHWnd)
         if right(lcTitle,1)=='*'
            lcTitle=alltrim(substr(lcTitle,1,len(lcTitle)-1))
         endif
         
         * Get file path
         lcPath = evl(this.GetFilePath(lcTitle), lcTitle)
         
         ltBeatTS = datetime()
         
         * Check if last heartbeat is at least 2min in the past
         if !llWrite and !empty(this.oBeats.GetKey(lcPath))
            ltLastBeat = this.oBeats.Item(lcPath)
            if ltLastBeat > ltBeatTS-120
               this.Dbg('Skip heartbeat for entry: ' + lcPath)
               exit
            endif
         endif
         
         * Remember last beat time
         if !empty(this.oBeats.GetKey(lcPath))
            this.oBeats.Remove(lcPath)
         endif
         this.oBeats.Add(ltBeatTS,lcPath)
         
         * Find CLI
         lcCli = this.GetWakatimeCLI()
         if empty(lcCli)
            exit
         endif
         
         * Get project
         if type("_VFP.ActiveProject.Name")=="C"
            lcProj=juststem(_VFP.ActiveProject.Name)
         else
            lcProj=''
         endif
         
         * Build wakatime params
         lcParams='--key '+this.cApiKey
         lcParams=lcParams+' --language FoxPro'
         lcParams=lcParams+' --plugin "VFP-IDE/'+alltrim(str(version(5)/100,5,2))+' VFP-wakatime/'+this.cVersion+'"'
         lcParams=lcParams+' --entity "'+lcPath+'"'
         if !empty(lcProj)
            lcParams=lcParams+' --project "'+lcProj+'"'
         endif
         if !empty(this.cProxy)
            lcParams=lcParams+' --proxy "'+this.cProxy+'"'
         endif
         if llWrite
            lcParams=lcParams+' --write'
         endif
         this.Dbg('SendHeartbeat: ' + lcParams)
         
         * Run CLI in background
         this.oSH.Run('"'+lcCli+'" '+lcParams,0,.f.)
         
      catch to loErr
         this.Exc(loErr)
      endtry
   endproc
   
   procedure GetFilePath
      lparameters lcTitle as string
      local loErr as Exception
      local lcResFile as string, lcData as string, lnIndex as Integer, lcPath as string
      
      * Try find file path in FoxResource (works for .prg)
      lcResFile=sys(2005)
      if empty(lcResFile)
         this.Err('No FoxPro RESOURCE in use. SET RESOURCE ON!')
      else
         if !used("FoxResource")
            use (lcResFile) alias FoxResource shared again
         endif
         go top in FoxResource
         select FoxResource
         locate for TYPE='PREFW' and ID='MRU' and UPDATED=date() and upper(lcTitle)$upper(DATA)
         if found() and !empty(DATA)
            lcData=chrtran(substr(DATA,3,len(Data)-5),chr(0),';')
            *this.Dbg('Data: '+lcData)
            lnIndex=1
            do while .t.
               lcPath=getwordnum(lcData,lnIndex,';')
               this.Dbg('Path: '+lcPath)
               lnIndex=lnIndex+1
               if empty(lcPath)
                  exit
               endif
               if upper(right(lcPath,len(lcTitle)))=upper(lcTitle)
                  return lcPath
               endif
            enddo
         endif
      endif
      
      * Try find file path in current project
*!*         if type("_VFP.ActiveProject.Name")=="C" and file(_VFP.ActiveProject.Name)
*!*            if used('ProjectFile')
*!*               use in ProjectFile
*!*            endif
*!*            use (_VFP.ActiveProject.Name) alias ProjectFile shared again
*!*            
*!*            * no idear how ?!
*!*         endif
      
      this.Err('Full file path was not found')
      return ''
   endproc
   
   procedure GetWakatimeCLI
      local lcPath as String
      local array laFiles[1,4]
      * WAKATIME_HOME
      lcPath=getenv("WAKATIME_HOME")
      
      * or USERPROFILE
      if empty(lcPath)
         lcPath=addbs(getenv("USERPROFILE"))+'.wakatime'
      endif
      
      * Create folder
      if !directory(lcPath)
         mkdir (lcPath)
      endif
      
      * Find CLI
      if adir(laFiles,addbs(lcPath)+'wakatime-cli-*.exe')>0
         return addbs(lcPath)+laFiles[1,1]
      endif
      
      this.Err('wakatime-cli not installed!')
      wait window 'Please download latest wakatime-cli from GitHub to '+lcPath timeout 2
      return ''
   endproc
   
   procedure WMEventHandler
      lparameters lnhWnd as integer, lnMsg as integer, lnwParam as integer, lnlParam as integer
      local loErr as Exception
      local lcWindowTitle as string
      local lnReturn as Integer
      
      if type("lnhWnd")#"N" or type("lnMsg")#"N"
         return
      endif
      
      try
         lcWindowTitle=this.GetWindowTitle(lnhWnd)
      
         do case
            * fix work area crash 
            cast lcWindowTitle = 'work area' and lnMsg == WM_CREATE
                 unbindevents(0, WM_CREATE, this, 'WMEventHandler')
                 bindevent(lnhWnd, WM_DESTROY, this, "WMEventHandler")
            cast lcWindowTitle = 'work area' and lnMsg == WM_DESTROY
                 unbindevents(lnhWnd, WM_DESTROY, this, 'WMEventHandler')
                 bindevent(0, WM_CREATE, this, "WMEventHandler")
                 
            * fix call stack crash
            case lcWindowTitle = 'call stack' and lnMsg == WM_CREATE
                 unbindevents(0, WM_CREATE, this, 'WMEventHandler')
                 bindevent(0, WM_ACTIVATE, this, "WMEventHandler")
            case lnMsg == WM_ACTIVATE
                 unbindevents(0, WM_ACTIVATE, this, 'WMEventHandler')
                 bindevent(0, WM_CREATE, this, "WMEventHandler")
                 
            case lnMsg == WM_CREATE
                 * Register events
                 this.Dbg('Bind window '+alltrim(str(lnhWnd)))
                 bindevent(lnhWnd, WM_SHOWWINDOW, this, "WMEventHandler")
                 bindevent(lnhWnd, WM_SETTEXT, this, "WMEventHandler")
                 
            case lnMsg == WM_SETTEXT
                 * Window title changed
                 this.WindowSetText(lnHWnd)
                 
            case lnMsg == WM_SHOWWINDOW
                 * Window opened
                 this.WindowShow(lnhWnd)
                 
            case lnMsg == WM_DESTROY
                 * Window destroyed
                 this.WindowDestroy(lnhWnd)
                 
            case lnMsg == WM_SETFOCUS
                 * Focus
                 if this.nLastHWnd # lnhWnd
                    this.nLastHWnd = lnhWnd
                    this.WindowSetFocus(lnhWnd)
                 endif
                  
            case lnMsg == WM_KEYUP
                 * Key input
                 this.WindowInput(lnhWnd)
                   
            case lnMsg == WM_LBUTTONUP
                 * Mouse input
                 this.WindowInput(lnhWnd)
         endcase
      catch to loErr
         this.Exc(loErr)
      endtry
      
      * Must pass on the message
      lnReturn = this.CallWindowProc(this.nVfpWndProc, lnhWnd, lnMsg, lnwParam, lnlParam)
   endproc
   
   procedure IsIDEWindow
      lparameters lnHWnd as integer
      
      local llReturn as boolean, lcWindowTitle as string, lnParentHWnd As integer
      local loErr as Exception
      
      local laToolBars[1]
      laToolBars=""
      adockstate(laToolBars,2)
      
      try 
         lcWindowTitle = this.GetWindowTitle(lnHWnd)
      
         llReturn = Application.hWnd # lnHWnd ;        && Ignore the main FoxPro window
                  and not Empty(lcWindowTitle) ;       && Ignore windows with no titles
                  and not inList(lower(lcWindowTitle), "compile", "debugger", "watch", "locals", "trace", "call stack", "debug output", "parentclass browser") ;
                  and not inList(lower(lcWindowTitle), "expression builder", "expression builder options") ;
                  and ascan(laToolbars,lcWindowTitle,-1,-1,1,7) = 0
         
         * Gather the hWnd of this windows parent
         lnParentHWnd = this.GetAncestor(lnHWnd, GA_PARENT)
         
         * Only allow children of _Screen
         llReturn = llReturn and lnParentHWnd = _Screen.hWnd   
         
         * Check the border style
         llReturn = llReturn and This.HasBorder(lnHWnd)
         
      catch to loErr
         this.Exc(loErr)
      endtry
      
      return llReturn
   endproc
   
   procedure HasBorder
      lparameters lnHWnd as integer
      local lcBuffer as String, lcStyle as String
      
      lcBuffer = space(200)
      
      this.GetWindowInfo(lnHWnd, @lcBuffer)
      
      * Parse WINDOWINFO struct
      lcStyle = ctobin(substr(lcBuffer, (4*9)+1, 4), "4rs")
      return bitand(lcStyle, WS_BORDER) = WS_BORDER
   endproc
   
   procedure GetWindowTitle
      lparameters lnHWnd as integer
      
      local lcBuffer as string
      lcBuffer = space(200)
      this.GetWindowText(lnHWnd,@lcBuffer,len(lcBuffer))
      
      lcBuffer=alltrim(chrtran(lcBuffer,chr(0),''))
      return lcBuffer
   endproc
   
   ********************************************************************************
   *                                   Logging                                    
   ******************************************************************************** 
   
   procedure LogEvent
      lparameters lcLevel as string,lcMsg as string
      if !empty(this.cLogPath)
         strtofile(ttoc(datetime(),3)+' '+padr(lcLevel,7)+lcMsg+chr(13)+chr(10),this.cLogPath,1)
      endif
   endproc
   
   procedure Dbg
      lparameters lcMsg as string
      this.LogEvent('DEBUG', lcMsg)
   endproc
   
   procedure Err
      lparameters lcErr as string
      this.LogEvent('ERROR', lcErr)
   endproc
   
   procedure Exc
      lparameters loErr as Exception
      this.LogEvent('ERROR', loErr.Message + chr(13)+chr(10) + loErr.Procedure + '(' + alltrim(str(loErr.LineNo)) + ')')
   endproc
   
   ********************************************************************************
   *                                  WIN32 API                                   
   ******************************************************************************** 
   
   procedure CallWindowProc
      lparameters lpPrevWndFunc, hWnd, nMsg, wParam, lParam
      declare integer CallWindowProc in Win32API integer lpPrevWndFunc, integer hWnd, integer nMsg, integer wParam, integer lParam
      return CallWindowProc(lpPrevWndFunc, hWnd, nMsg, wParam, lParam)
   endproc
   
   procedure GetWindowInfo
      lparameters lnHWnd, pwindowinfo
      declare integer GetWindowInfo in Win32API integer hWnd, string @ pwindowinfo
      return GetWindowInfo(lnHWnd, @pwindowinfo)
   endproc
   
   procedure GetAncestor
      lparameters lnHWnd, lgaFlags
      declare integer GetAncestor in Win32API integer hWnd, integer gaFlags
      return GetAncestor(lnHWnd, lgaFlags)
   endproc
   
   procedure GetWindowLong
      lparameters lnHWnd, lnIndex
      declare integer GetWindowLong in Win32API integer hWnd, integer nIndex
      return GetWindowLong(lnHWnd, lnIndex)
   endproc
   
   procedure GetWindowText
      lparameters lnHWnd, lszText, lnLen
      declare integer GetWindowText in Win32API integer hWnd, string @szText, integer nLen
      return GetWindowText(lnHWnd, @lszText, lnLen)
   endproc
enddefine

define class CWindow as custom
   nHWnd = 0
   cTitle = ''
enddefine
