!===================================================================================================================================
!()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()!
!===================================================================================================================================
!>
!!##NAME
!!    M_CLI(3fm) - [ARGUMENTS::M_CLI] - command line argument parsing using a prototype command
!!    (LICENSE:PD)
!!##SYNOPSIS
!!
!!    use M_CLI, only : get_commandline, print_dictionary, unnamed
!!    use M_CLI, only : debug
!!
!!##DESCRIPTION
!!    Allow for command line parsing much like standard Unix command line parsing using a simple prototype. 
!!
!!##EXAMPLE
!!
!!   Sample program
!!
!!##AUTHOR
!!    John S. Urban, 2019
!!##LICENSE
!!    Public Domain
!===================================================================================================================================
module M_CLI
use, intrinsic :: iso_fortran_env, only : stderr=>ERROR_UNIT,stdin=>INPUT_UNIT    ! access computing environment
private
!===================================================================================================================================
public  :: get_commandline
public  :: print_dictionary
public debug
public unnamed

private :: longest_command_argument
private :: prototype_and_cmd_args_to_nlist
private :: prototype_to_dictionary
private :: update
private :: get
private :: wipe_dictionary

type option
   character(:),allocatable :: shortname
   character(:),allocatable :: longname
   character(:),allocatable :: value
   integer                  :: length
   logical                  :: present_in
end type option
!===================================================================================================================================
character(len=:),allocatable   :: keywords(:)
character(len=:),allocatable   :: values(:)
integer,allocatable            :: counts(:)
logical,allocatable            :: present_in(:)

logical                        :: keyword_single=.true.
character(len=:),allocatable   :: passed_in
character(len=:),allocatable   :: namelist_name

character(len=:),allocatable   :: unnamed(:)
logical                        :: debug=.false.
logical                        :: return_all
!===================================================================================================================================
private dictionary

type dictionary
   character(len=:),allocatable :: key(:)
   character(len=:),allocatable :: value(:)
   integer,allocatable          :: count(:)
   contains
      procedure,private :: get => dict_get
      procedure,private :: set => dict_add    ! insert entry by name into a sorted allocatable character array if it is not present
      procedure,private :: del => dict_delete ! delete entry by name from a sorted allocatable character array if it is present
end type dictionary
!===================================================================================================================================
private locate        ! [M_list] find PLACE in sorted character array where value can be found or should be placed
   private locate_c
   private locate_d
   private locate_r
   private locate_i
private insert        ! [M_list] insert entry into a sorted allocatable array at specified position
   private insert_c
   private insert_d
   private insert_r
   private insert_i
   private insert_l
private replace       ! [M_list] replace entry by index from a sorted allocatable array if it is present
   private replace_c
   private replace_d
   private replace_r
   private replace_i
   private replace_l
private remove        ! [M_list] delete entry by index from a sorted allocatable array if it is present
   private remove_c
   private remove_d
   private remove_r
   private remove_i
   private remove_l

interface locate
   module procedure locate_c, locate_d, locate_r, locate_i
end interface

interface insert
   module procedure insert_c, insert_d, insert_r, insert_i, insert_l
end interface

interface replace
   module procedure replace_c, replace_d, replace_r, replace_i, replace_l
end interface

interface remove
   module procedure remove_c, remove_d, remove_r, remove_i, remove_l
end interface
!===================================================================================================================================
contains
!===================================================================================================================================
!()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()!
!===================================================================================================================================
!>
!!##NAME
!!    get_commandline(3f) - [ARGUMENTS:M_CLI] command line argument parsing
!!    (LICENSE:PD)
!!
!!##SYNOPSIS
!!
!!   function get_commandline(definition) result(string)
!!
!!    character(len=*),intent(in),optional  :: definition
!!    character(len=:),allocatable :: string
!!##DESCRIPTION
!!
!!    To use the routine first define a NAMELIST group called ARGS.
!!
!!    This routine leverages NAMELIST groups to do the conversion from strings
!!    to numeric values required by other command line parsers.
!!
!!    The example program shows how simple it is to use. Add a
!!    variable to the NAMELIST and the prototype and it automatically is available as
!!    a value in the program. 
!!
!!    There is no need to convert from strings to numeric
!!    values in the source code. Even arrays and user-defined types can be
!!    used, complex values can be input ... just define the variable in the prototype and
!!    add it to the NAMELIST definition.
!!
!!    Note that since all the arguments are defined in a NAMELIST group
!!    that config files can easily be used for the same options.
!!    Just create a NAMELIST input file and read it.
!!
!!    NAMELIST syntax can vary between different programming environments.
!!    Currently, this routine has only been tested using gfortran 7.0.4;
!!    and requires at least Fortran 2003.
!!
!!    For example:
!!
!!       program show_get_commandline_unix_prototype
!!          use M_CLI,  only : unnamed, get_commandline, print_dictionary
!!          implicit none
!!          integer                      :: i
!!          character(len=255)           :: message ! for I/O error messages
!!          character(len=:),allocatable :: readme ! stores updated namelist
!!          integer                      :: ios
!!
!!       ! declare a namelist
!!          real               :: x, y, z, point(3)
!!          character(len=80)  :: title
!!          logical            :: help, version, l, l_, v, h
!!          equivalence       (help,h),(version,v)
!!          namelist /args/ x,y,z,point,title,help,h,version,v,l,l_
!!
!!       ! Define the prototype
!!       !  o All parameters must be listed with a default value
!!       !  o string values  must be double-quoted
!!       !  o numeric lists must be comma-delimited. No spaces are allowed
!!       !  o all long names must be lowercase. An uppercase short name
!!       !    -A maps to variable A_
!!       !  o if variables are equivalenced only one should be used on 
!!       !    the command line
!!          character(len=*),parameter  :: cmd='&
!!          & -x 1 -y 2 -z 3     &
!!          & --point -1,-2,-3   &
!!          & --title "my title" &
!!          & -h --help          &
!!          & -v --version       &
!!          & -l -L'
!!          ! reading in a NAMELIST definition defining the entire NAMELIST
!!          readme=get_commandline(cmd)
!!          read(readme,nml=args,iostat=ios,iomsg=message)
!!          if(ios.ne.0)then
!!             write(*,'("ERROR:",i0,1x,a)')ios, trim(message)
!!             call print_dictionary('OPTIONS:')
!!             stop 1
!!          endif
!!          ! all done cracking the command line
!!
!!          ! use the values in your program.
!!          write(*,nml=args)
!!          ! the optional unnamed values on the command line are
!!          ! accumulated in the character array "UNNAMED"
!!          if(size(unnamed).gt.0)then
!!             write(*,'(a)')'files:'
!!             write(*,'(i6.6,3a)')(i,'[',unnamed(i),']',i=1,size(unnamed))
!!          endif
!!       end program show_get_commandline_unix_prototype
!!
!!##OPTIONS
!!
!!    DESCRIPTION   composed of all command arguments concatenated
!!                  into a Unix-like command prototype string.
!!
!!                  o all values except logicals get a value.
!!                  o long names (--keyword) should be all lowercase
!!                  o short names (-letter) that are uppercase map to a
!!                    NAMELIST variable called "letter_", but lowercase
!!                    short names map to NAMELIST name "letter".
!!                  o strings MUST be delimited with double-quotes and
!!                    must be at least one space and internal
!!                    double-quotes are represented with two double-quotes
!!                  o lists of numbers should be comma-delimited.
!!                     No spaces are allowed in lists of numbers.
!!                  o the values follow the rules for NAMELIST values, so
!!                    "-p 2*0" for example would define two values.
!!
!!##RETURNS
!!
!!    STRING   The output is a NAMELIST string than can be read to update
!!             the NAMELIST "ARGS" with the keywords that were supplied on
!!             the command line.
!!
!!    When using one of the Unix-like command line forms note that
!!    (subject to change) the following variations from other common
!!    command-line parsers:
!!
!!       o long names do not take the --KEY=VALUE form, just
!!         --KEY VALUE; and long names should be all lowercase and
!!         always more than one character.
!!
!!       o duplicate keywords are replaced by the rightmost entry
!!
!!       o numeric keywords are not allowed; but this allows
!!         negative numbers to be used as values.
!!
!!       o mapping of short names to long names is via an EQUIVALENCE.
!!         specifying both names of an equivalenced keyword will have
!!         undefined results (currently, their alphabetical order
!!         will define what the Fortran variable values become).
!!
!!       o short keywords cannot be combined. -a -b -c is required,
!!         not -abc even for Boolean keys.
!!
!!       o shuffling is not supported. Values must follow their
!!         keywords.
!!
!!       o if a parameter value of just "-" is supplied it is
!!         converted to the string "stdin".
!!
!!       o if the keyword "--" is encountered the rest of the
!!         command arguments go into the character array "UNUSED".
!!
!!       o values not matching a keyword go into the character
!!         array "UNUSED".
!!
!!       o short-name parameters of the form -LETTER VALUE
!!         map to a NAMELIST name of LETTER_ if uppercase
!!
!!##AUTHOR
!!    John S. Urban, 2019
!!##LICENSE
!!    Public Domain
!===================================================================================================================================
function get_commandline(definition) result (readme)

character(len=*),parameter::ident_2="@(#)M_CLI::get_commandline(3f): return all command arguments as a NAMELIST(3f) string to read"

character(len=*),intent(in),optional :: definition
character(len=:),allocatable         :: hold               ! stores command line argument
character(len=:),allocatable         :: readme             ! stores command line argument
integer                              :: ibig
   if(allocated(unnamed))then
       deallocate(unnamed)
   endif
   ibig=longest_command_argument() ! bug in gfortran. len=0 should be fine
   allocate(character(len=ibig) :: unnamed(0))
   return_all=.true.
   if(present(definition))then
      if(definition.eq.'')then
         write(*,*)'*get_commandline* blank definition'
      else
         call wipe_dictionary()
         hold=adjustl(definition)
         call prototype_and_cmd_args_to_nlist(hold,readme)
      endif
   else                                                    ! assume should read command line as a raw string in NAMELIST format
      write(*,*)'*get_commandline* missing definition'
   endif

   if(.not.allocated(unnamed))then
       allocate(character(len=0) :: unnamed(0))
   endif

end function get_commandline
!===================================================================================================================================
!()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()!
!===================================================================================================================================
!>
!!##NAME
!!    prototype_to_dictionary(3f) - [ARGUMENTS:M_CLI] parse user command and store tokens into dictionary
!!    (LICENSE:PD)
!!
!!##SYNOPSIS
!!
!!   subroutine prototype_to_dictionary(string)
!!
!!    character(len=*),intent(in)     ::  string
!!
!!##DESCRIPTION
!!    given a string of form
!!
!!      -var value -var value
!!
!!    define dictionary of form
!!
!!      keyword(i), value(i)
!!
!!    o  string values
!!
!!        o must be delimited with double quotes.
!!        o adjacent double quotes put one double quote into value
!!        o must not be null. A blank is specified as " ", not "".
!!
!!    o  logical values
!!
!!        o logical values must not have a value
!!
!!    o  leading and trailing blanks are removed from unquoted values
!!
!!
!!##OPTIONS
!!
!!    STRING   string is character input string to define command
!!
!!##RETURNS
!!
!!##EXAMPLE
!!
!!   sample program:
!!
!!   Results:
!!
!!##AUTHOR
!!    John S. Urban, 2019
!!##LICENSE
!!    Public Domain
!===================================================================================================================================
subroutine prototype_to_dictionary(string)
implicit none

character(len=*),parameter::ident_4="@(#)M_CLI::prototype_to_dictionary(3f): parse user command and store tokens into dictionary"

character(len=*),intent(in)       :: string ! string is character input string of options and values

character(len=:),allocatable      :: dummy   ! working copy of string
character(len=:),allocatable      :: value
character(len=:),allocatable      :: keyword
character(len=3)                  :: delmt   ! flag if in a delimited string or not
character(len=1)                  :: currnt  ! current character being processed
character(len=1)                  :: prev    ! character to left of CURRNT
character(len=1)                  :: forwrd  ! character to right of CURRNT
integer,dimension(2)              :: ipnt
integer                           :: islen   ! number of characters in input string
integer                           :: ipoint
integer                           :: itype
integer                           :: ifwd
integer                           :: ibegin
integer                           :: iend

   islen=len_trim(string)                               ! find number of characters in input string
   if(islen  ==  0)then                                 ! if input string is blank, even default variable will not be changed
      return
   endif
   dummy=string//'  '

   keyword=""          ! initial variable name
   value=""            ! initial value of a string
   ipoint=0            ! ipoint is the current character pointer for (dummy)
   ipnt(2)=2           ! pointer to position in parameter name
   ipnt(1)=1           ! pointer to position in parameter value
   itype=1             ! itype=1 for value, itype=2 for variable

   delmt="off"
   prev=" "

   keyword_single=.true.
   do
      ipoint=ipoint+1               ! move current character pointer forward
      currnt=dummy(ipoint:ipoint)   ! store current character into currnt
      ifwd=min(ipoint+1,islen)
      forwrd=dummy(ifwd:ifwd)       ! next character (or duplicate if last)

      if((currnt=="-".and.prev==" ".and.delmt == "off".and.index("0123456789.",forwrd) == 0).or.ipoint > islen)then
         ! beginning of a parameter name
         if(forwrd.eq.'-')then                      ! change --var to -var so "long" syntax is supported
            dummy(ifwd:ifwd)='_'
            ipoint=ipoint+1                         ! ignore second - instead
            keyword_single=.false.
         else
            keyword_single=.true.
         endif
         if(ipnt(1)-1 >= 1)then
            ibegin=1
            iend=len_trim(value(:ipnt(1)-1))
            do
               if(iend  ==  0)then                  ! len_trim returned 0, parameter value is blank
                  iend=ibegin
                  exit
               elseif(value(ibegin:ibegin) == " ")then
                  ibegin=ibegin+1
               else
                  exit
               endif
            enddo
            if(keyword.ne.' ')then
               call update(keyword,value)         ! store name and its value
            else
               write(stderr,*)'*prototype_to_dictionary* warning: ignoring blank keyword ',trim(value)
            endif
         else
            if(keyword.ne.' ')then
               call update(keyword,'F')           ! store name and null value
            else
               if(debug)then
                  write(stderr,*)'*prototype_to_dictionary* warning: blank keyword, and ignoring blank value',trim(value)
               endif
            endif
         endif
         itype=2                               ! change to filling a variable name
         value=""                              ! clear value for this variable
         keyword=""                            ! clear variable name
         ipnt(1)=1                             ! restart variable value
         ipnt(2)=1                             ! restart variable name

      else       ! currnt is not one of the special characters
         ! the space after a keyword before the value
         if(currnt == " ".and.itype  ==  2)then
            ! switch from building a keyword string to building a value string
            itype=1
            ! beginning of a delimited parameter value
         elseif(currnt  ==  """".and.itype  ==  1)then
            ! second of a double quote, put quote in
            if(prev  ==  """")then
               if(itype.eq.1)then
                  value=value//currnt
               else
                  keyword=keyword//currnt
               endif
               ipnt(itype)=ipnt(itype)+1
               delmt="on"
            elseif(delmt  ==  "on")then     ! first quote of a delimited string
               delmt="off"
            else
               delmt="on"
            endif
            if(prev /= """")then  ! leave quotes where found them
               if(itype.eq.1)then
                  value=value//currnt
               else
                  keyword=keyword//currnt
               endif
               ipnt(itype)=ipnt(itype)+1
            endif
         else     ! add character to current parameter name or parameter value
            if(itype.eq.1)then
               value=value//currnt
            else
               keyword=keyword//currnt
            endif
            ipnt(itype)=ipnt(itype)+1
         endif

      endif

      prev=currnt
      if(ipoint <= islen)then
         cycle
      endif
      exit
   enddo

end subroutine prototype_to_dictionary
!===================================================================================================================================
!()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()!
!===================================================================================================================================
!>
!!##NAME
!!    update(3f) - [ARGUMENTS:M_CLI] update internal dictionary given keyword and value
!!    (LICENSE:PD)
!!##SYNOPSIS
!!
!!   subroutine update(key,val)
!!
!!    character(len=*),intent(in)           :: key
!!    character(len=*),intent(in),optional  :: val
!!##DESCRIPTION
!!    Update internal dictionary in M_CLI(3fm) module.
!!##OPTIONS
!!    key  name of keyword to add, replace, or delete from dictionary
!!    val  if present add or replace value associated with keyword. If not
!!         present remove keyword entry from dictionary.
!!##RETURNS
!!##EXAMPLE
!!
!!##AUTHOR
!!    John S. Urban, 2019
!!##LICENSE
!!    Public Domain
!===================================================================================================================================
subroutine update(key,val)
character(len=*),intent(in)           :: key
character(len=*),intent(in),optional  :: val
integer                               :: place
integer                               :: ilen
character(len=:),allocatable          :: val_local
   if(debug)then
      if(present(val))then
         write(stderr,*)'*update* DEBUG: KEY=',key,' VAL=',val
      else
         write(stderr,*)'*update* DEBUG: KEY=',key
      endif
   endif
   if(present(val))then
      val_local=val
      ilen=len_trim(val_local)
      call locate(keywords,key,place)                   ! find where string is or should be
      if(place.lt.1)then                                ! if string was not found insert it
         call insert(keywords,key,iabs(place))
         call insert(values,val_local,iabs(place))
         call insert(counts,ilen,iabs(place))
         call insert(present_in,.true.,iabs(place))
      else
         call replace(values,val_local,place)
         call replace(counts,ilen,place)
         call replace(present_in,.true.,place)
      endif
   else                                                 ! if no value is present remove the keyword and related values
      call locate(keywords,key,place)
      if(place.gt.0)then
         call remove(keywords,place)
         call remove(values,place)
         call remove(counts,place)
         call remove(present_in,place)
      endif
   endif
   if(debug)then
      if(present(val))then
         write(stderr,*)'*update* DEBUG: KEY=',key,'PLACE=',place,' VAL=',val, &
                &size(keywords),size(values),size(counts),size(present_in)
      else
         write(stderr,*)'*update* DEBUG: KEY=',key,'PLACE=',place,size(keywords),size(values),size(counts),size(present_in)
      endif
      write(stderr,*)present_in
   endif
end subroutine update
!===================================================================================================================================
!()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()!
!===================================================================================================================================
!>
!!##NAME
!!    wipe_dictionary(3fp) - [ARGUMENTS:M_CLI] reset private M_CLI(3fm) dictionary to empty
!!    (LICENSE:PD)
!!##SYNOPSIS
!!
!!    subroutine wipe_dictionary()
!!##DESCRIPTION
!!    reset private M_CLI(3fm) dictionary to empty
!!##EXAMPLE
!!
!!    program demo_wipe_dictionary
!!    use M_CLI, only : dictionary
!!       call wipe_dictionary()
!!    end program demo_wipe_dictionary
!!##AUTHOR
!!    John S. Urban, 2019
!!##LICENSE
!!    Public Domain
!===================================================================================================================================
subroutine wipe_dictionary()
   if(allocated(keywords))deallocate(keywords)
   allocate(character(len=0) :: keywords(0))
   if(allocated(values))deallocate(values)
   allocate(character(len=0) :: values(0))
   if(allocated(counts))deallocate(counts)
   allocate(counts(0))
   if(allocated(present_in))deallocate(present_in)
   allocate(present_in(0))
end subroutine wipe_dictionary
!===================================================================================================================================
!()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()!
!===================================================================================================================================
!>
!!##SYNOPSIS
!!
!!    get(3f) - [ARGUMENTS:M_CLI] get dictionary value associated with key name in private M_CLI(3fm) dictionary
!!##DESCRIPTION
!!    Get dictionary value associated with key name in private M_CLI(3fm) dictionary.
!!##OPTIONS
!!##RETURNS
!!##EXAMPLE
!!
!===================================================================================================================================
function get(key) result(valout)
character(len=*),intent(in)   :: key
character(len=:),allocatable  :: valout
integer                       :: place
   ! find where string is or should be
   call locate(keywords,key,place)
   if(place.lt.1)then
      valout=''
   else
      valout=values(place)(:counts(place))
   endif
end function get
!===================================================================================================================================
!()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()!
!===================================================================================================================================
!>
!!##NAME
!!    prototype_and_cmd_args_to_nlist(3f) - [ARGUMENTS:M_CLI] convert Unix-like command arguments to namelist
!!    (LICENSE:PD)
!!##SYNOPSIS
!!
!!   subroutine prototype_and_cmd_args_to_nlist(prototype,nml)
!!
!!    character(len=*)             :: prototype
!!    character(len=:),allocatable :: nml
!!##DESCRIPTION
!!    create dictionary with character keywords, values, and value lengths using the routines for maintaining a list from
!!    command line arguments.
!!##OPTIONS
!!    prototype
!!##RETURNS
!!    nml
!!##EXAMPLE
!!
!!   Sample program
!!    program demo_M_list
!!    use M_CLI,  only : prototype_and_cmd_args_to_nlist, unnamed, debug
!!    implicit none
!!    character(len=:),allocatable :: readme
!!    character(len=256)           :: message
!!    integer                      :: ios
!!    integer                      :: i
!!    doubleprecision              :: something
!!
!!    ! define namelist
!!    ! lowercase keywords
!!    logical            :: l,h,v
!!    real               :: p(2)
!!    complex            :: c
!!    doubleprecision    :: x,y,z
!!
!!    ! uppercase keywords get an underscore
!!    logical            :: l_,h_,v_
!!    character(len=256) :: a_,b_                  ! character variables must be long enough to hold returned value
!!    integer            :: c_(3)
!!    namelist /args/ l,h,v,p,c,x,y,z,a_,b_,c_,l_,h_,v_
!!
!!       debug=.true.
!!       ! give command template with default values
!!       ! all values except logicals get a value.
!!       ! strings must be delimited with double quotes
!!       ! A string has to have at least one character as for -A
!!       ! lists of numbers should be comma-delimited. No spaces are allowed in lists of numbers
!!       ! the values follow the rules for NAMELIST input, so  -p 2*0 would define two values.
!!       call prototype_and_cmd_args_to_nlist('-l -v -h -LVH -x 0 -y 0.0 -z 0.0d0 -p 0,0 -A " " -B "Value B" -C 10,20,30 -c (-123,-456)',readme)
!!       read(readme,nml=args,iostat=ios,iomsg=message)
!!       if(ios.ne.0)then
!!          write(*,*)'ERROR:',trim(message)
!!          write(*,'("INPUT WAS ",a)')readme
!!          write(*,args)
!!          stop 3
!!       else
!!          something=sqrt(x**2+y**2+z**2)
!!          write(*,*)something,x,y,z
!!          if(size(unnamed).gt.0)then
!!             write(*,'(a)')'files:'
!!             write(*,'(i6.6,3a)')(i,'[',unnamed(i),']',i=1,size(unnamed))
!!          endif
!!       endif
!!    end program demo_M_list
!!##AUTHOR
!!    John S. Urban, 2019
!!##LICENSE
!!    Public Domain
!===================================================================================================================================
subroutine prototype_and_cmd_args_to_nlist(prototype,nml)
implicit none

character(len=*),parameter::ident_5="&
&@(#)M_CLI::prototype_and_cmd_args_to_nlist: create dictionary from prototype (if not null) and update from command line arguments"

character(len=*)             :: prototype
character(len=:),allocatable :: nml
integer                      :: i
integer                      :: ibig
   if(debug)then
      write(stderr,*)'*prototype_and_cmd_args_to_nlist* DEBUG: prototype=',trim(prototype)
   endif

   passed_in=prototype ! make global copy for printing

   if(allocated(unnamed))deallocate(unnamed)
   ibig=longest_command_argument() ! bug in gfortran. len=0 should be fine
   allocate(character(len=ibig) ::unnamed(0))

   if(prototype.ne.'')then
      call prototype_to_dictionary(prototype)  ! build dictionary from prototype
      namelist_name='&ARGS'
      present_in=.false.  ! reset all values to false
   endif

   if(debug)then                            ! look at some of the values as strings or numbers
      call print_dictionary('DICTIONARY FROM PROTOTYPE')
   endif

   call cmd_args_to_dictionary(check=.true.)

   call dictionary_to_namelist(nml)

   ! show array
   if(debug)then
      call print_dictionary('DICTIONARY FROM COMMAND LINE:')
   endif

end subroutine prototype_and_cmd_args_to_nlist
!===================================================================================================================================
!()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()!
!===================================================================================================================================
subroutine cmd_args_to_dictionary(check)
! convert command line arguments to dictionary entries
! reading the namelist output will trap unknown option names so do not really need to trap them here
logical,intent(in),optional  :: check
logical                      :: check_local
integer                      :: pointer
character(len=:),allocatable :: lastkeyword
integer                      :: i
integer                      :: ilength, istatus, imax
character(len=:),allocatable :: current_argument
character(len=:),allocatable :: current_argument_padded
character(len=:),allocatable :: dummy
character(len=:),allocatable :: oldvalue
logical                      :: nomore
   if(present(check))then
      check_local=check
   else
      check_local=.false.
   endif
   nomore=.false.
   pointer=0
   lastkeyword=' '
   keyword_single=.true.
   GET_ARGS: do i=1, command_argument_count()                                                        ! insert and replace entries
      call get_command_argument(number=i,length=ilength,status=istatus)                              ! get next argument
      if(istatus /= 0) then                                                                          ! stop program on error
         write(stderr,*)'*prototype_and_cmd_args_to_nlist* error obtaining argument ',i,&
            &'status=',istatus,&
            &'length=',ilength
         exit GET_ARGS
      else
         if(allocated(current_argument))deallocate(current_argument)
         ilength=max(ilength,1)
         allocate(character(len=ilength) :: current_argument)
         call get_command_argument(number=i,value=current_argument,length=ilength,status=istatus)    ! get next argument
         if(istatus /= 0) then                                                                       ! stop program on error
            write(stderr,*)'*prototype_and_cmd_args_to_nlist* error obtaining argument ',i,&
               &'status=',istatus,&
               &'length=',ilength,&
               &'target length=',len(current_argument)
            exit GET_ARGS
          endif
      endif

      if(current_argument.eq.'-')then  ! sort of
         current_argument='"stdin"'
      endif
      if(current_argument.eq.'--')then ! everything after this goes into the unnamed array
         nomore=.true.
         pointer=0
         cycle
      endif
      dummy=current_argument//'   '
      current_argument_padded=current_argument//'   '
      if(.not.nomore.and.current_argument_padded(1:2).eq.'--'.and.index("0123456789.",dummy(3:3)).eq.0)then ! beginning of long word
         keyword_single=.false.
         if(lastkeyword.ne.'')then
            call ifnull()
         endif
         call locate(keywords,current_argument_padded(3:),pointer)
         if(pointer.le.0.and.check_local)then
            call print_dictionary('UNKNOWN LONG KEYWORD: '//current_argument)
            stop 1
         endif
         lastkeyword=trim(current_argument_padded(3:))
      elseif(.not.nomore.and.current_argument_padded(1:1).eq.'-'.and.index("0123456789.",dummy(2:2)).eq.0)then  ! short word
         keyword_single=.true.
         if(lastkeyword.ne.'')then
            call ifnull()
         endif
         call locate(keywords,current_argument_padded(2:),pointer)
         if(pointer.le.0.and.check_local)then
            call print_dictionary('UNKNOWN SHORT KEYWORD: '//current_argument)
            stop 2
         endif
         lastkeyword=trim(current_argument_padded(2:))
      elseif(pointer.eq.0)then                                                                           ! unnamed arguments
         imax=max(len(unnamed),len(current_argument))
         unnamed=[character(len=imax) :: unnamed,current_argument]
      else
         if(debug)then
            write(stderr,*)'POINTER=',pointer,' KEYWORD=',keywords(pointer),' VALUE=',current_argument,' LENGTH=',ilength
         endif
         oldvalue=get(keywords(pointer))//' '
         if(oldvalue(1:1).eq.'"')then
            current_argument=quote(current_argument(:ilength))
         endif
         if(upper(oldvalue).eq.'F'.or.upper(oldvalue).eq.'T')then  ! assume boolean parameter
            if(current_argument.ne.' ')then
               imax=max(len(unnamed),len(current_argument))
               unnamed=[character(len=imax) :: unnamed,current_argument]
            endif
            current_argument='T'
         endif
         call update(keywords(pointer),current_argument)
         pointer=0
         lastkeyword=''
      endif
   enddo GET_ARGS
   if(lastkeyword.ne.'')then
      call ifnull()
   endif


contains
subroutine ifnull()
   oldvalue=get(lastkeyword)//' '
   if(upper(oldvalue).eq.'F'.or.upper(oldvalue).eq.'T')then
      call update(lastkeyword,'T')
   elseif(oldvalue(1:1).eq.'"')then
      call update(lastkeyword,'" "')
   else
      call update(lastkeyword,' ')
   endif
end subroutine ifnull

end subroutine cmd_args_to_dictionary
!===================================================================================================================================
!()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()!
!===================================================================================================================================
subroutine dictionary_to_namelist(nml)
character(len=:),allocatable,intent(out) :: nml
integer :: i
character(len=:),allocatable :: newkeyword
   ! build namelist string
   nml=namelist_name//' '
   if(return_all)then  ! if returning all first do keywords not present on command line so equivalences work
      do i=1,size(keywords)
         if(isupper(keywords(i)(1:1)))then
            newkeyword=trim(lower(keywords(i)))//'_'
         else
            newkeyword=trim(keywords(i))
         endif
         if(.not.present_in(i))then
            nml=nml//newkeyword//'='//trim(values(i))//' '
         endif
      enddo
   endif

   do i=1,size(keywords)  ! now only do keywords present on command line
      if(isupper(keywords(i)(1:1)))then
         newkeyword=trim(lower(keywords(i)))//'_'
      else
         newkeyword=trim(keywords(i))
      endif
      if(present_in(i))then
         nml=nml//newkeyword//'='//trim(values(i))//' '
      endif
   enddo

   nml=nml//' /'
   if(debug)then
      write(stderr,'(a)')'NAMELIST:'
      write(stderr,'(a)')nml
      if(size(unnamed).gt.0)then
         write(stderr,'(a)')'UNNAMED'
         write(stderr,'(i6.6,3a)')(i,'[',unnamed(i),']',i=1,size(unnamed))
      endif
   endif
end subroutine dictionary_to_namelist
!===================================================================================================================================
!()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()!
!===================================================================================================================================
!>
!!##NAME
!!   print_dictionary(3f) - [ARGUMENTS:M_CLI] print internal dictionary created by calls to get_commandline(3f)
!!   (LICENSE:PD)
!!##SYNOPSIS
!!
!!   subroutine print_dictionary(header)
!!
!!    character(len=*),intent(in),optional :: header
!!##DESCRIPTION
!!   Print the internal dictionary created by calls to get_commandline(3f).
!!   This routine is intended to print the state of the argument list
!!   if an error occurs in using the get_commandline(3f) procedure..
!!##OPTIONS
!!   HEADER  label to print before printing the state of the command
!!           argument list.
!!##EXAMPLE
!!
!!    Typical usage:
!!
!!     program demo_get_commandline
!!     use M_CLI,  only : unnamed, get_commandline, print_dictionary
!!     implicit none
!!     integer                      :: i
!!     character(len=255)           :: message ! use for I/O error messages
!!     character(len=:),allocatable :: readme  ! stores updated namelist
!!     integer                      :: ios
!!     real               :: x, y, z
!!     logical            :: help, h
!!     equivalence       (help,h)
!!     namelist /args/ x,y,z,help,h
!!     character(len=*),parameter :: cmd='&ARGS X=1 Y=2 Z=3 HELP=F H=F /'
!!     ! initialize namelist from string and then update from command line
!!     readme=cmd
!!     read(readme,nml=args,iostat=ios,iomsg=message)
!!     if(ios.eq.0)then
!!        ! update cmd with options from command line
!!        readme=get_commandline(cmd)
!!        read(readme,nml=args,iostat=ios,iomsg=message)
!!     endif
!!     if(ios.ne.0)then
!!        write(*,'("ERROR:",i0,1x,a)')ios, trim(message)
!!        call print_dictionary('OPTIONS:')
!!        stop 1
!!     endif
!!     ! all done cracking the command line
!!     ! use the values in your program.
!!     write(*,nml=args)
!!     ! the optional unnamed values on the command line are
!!     ! accumulated in the character array "UNNAMED"
!!     if(size(unnamed).gt.0)then
!!        write(*,'(a)')'files:'
!!        write(*,'(i6.6,3a)')(i,'[',unnamed(i),']',i=1,size(unnamed))
!!     endif
!!     end program demo_get_commandline
!!
!!    Sample output
!!
!!    Calling the sample program with an unknown
!!    parameter produces the following:
!!
!!       $ ./print_dictionary -A
!!       UNKNOWN SHORT KEYWORD: -A
!!       KEYWORD             PRESENT  VALUE
!!       z                   F        [3]
!!       y                   F        [2]
!!       x                   F        [1]
!!       help                F        [F]
!!       h                   F        [F]
!!
!!       STOP 2
!!
!!##AUTHOR
!!    John S. Urban, 2019
!!##LICENSE
!!    Public Domain
!===================================================================================================================================
subroutine print_dictionary(header)
character(len=*),intent(in),optional :: header
integer          :: i
   if(present(header))then
      if(header.ne.'')then
         write(stderr,'(a)')header
      endif
   endif
   if(allocated(keywords))then
      if(size(keywords).gt.0)then
         write(stderr,'(*(a,t21,a,t30,a))')'KEYWORD','PRESENT','VALUE'
         write(stderr,'(*(a,t21,l1,t30,"[",a,"]",/))')(trim(keywords(i)),present_in(i),values(i)(:counts(i)),i=1,size(keywords))
      endif
   endif
   if(allocated(unnamed))then
      if(size(unnamed).gt.0)then
         write(stderr,'(a)')'UNNAMED'
         write(stderr,'(i6.6,3a)')(i,'[',unnamed(i),']',i=1,size(unnamed))
      endif
   endif
end subroutine print_dictionary
!===================================================================================================================================
!()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()!
!===================================================================================================================================
!>
!!##NAME
!!    longest_command_argument(3f) - [ARGUMENTS:M_CLI] length of longest argument on command line
!!    (LICENSE:PD)
!!##SYNOPSIS
!!
!!    function longest_command_argument() result(ilongest)
!!
!!     integer :: ilongest
!!
!!##DESCRIPTION
!!    length of longest argument on command line. Useful when allocating storage for holding arguments.
!!##RESULT
!!    longest_command_argument  length of longest command argument
!!##EXAMPLE
!!
!!   Sample program
!!
!!    program demo_longest_command_argument
!!    use M_CLI, only : longest_command_argument
!!       write(*,*)'longest argument is ',longest_command_argument()
!!    end program demo_longest_command_argument
!!##AUTHOR
!!    John S. Urban, 2019
!!##LICENSE
!!    Public Domain
!===================================================================================================================================
function longest_command_argument() result(ilongest)
integer :: i
integer :: ilength
integer :: istatus
integer :: ilongest
   ilength=0
   ilongest=0
   GET_LONGEST: do i=1,command_argument_count()                             ! loop throught command line arguments to find longest
      call get_command_argument(number=i,length=ilength,status=istatus)     ! get next argument
      if(istatus /= 0) then                                                 ! stop program on error
         write(stderr,*)'*prototype_and_cmd_args_to_nlist* error obtaining length for argument ',i
         exit GET_LONGEST
      elseif(ilength.gt.0)then
         ilongest=max(ilongest,ilength)
      endif
   enddo GET_LONGEST
end function longest_command_argument
!===================================================================================================================================
!()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()!
!===================================================================================================================================
! COPY OF M_LIST
!===================================================================================================================================
subroutine locate_c(list,value,place,ier,errmsg)

character(len=*),parameter::ident_5="&
&@(#)M_list::locate_c(3f): find PLACE in sorted character array where VALUE can be found or should be placed"

character(len=*),intent(in)             :: value
integer,intent(out)                     :: place
character(len=:),allocatable            :: list(:)
integer,intent(out),optional            :: ier
character(len=*),intent(out),optional   :: errmsg
integer                                 :: i
character(len=:),allocatable            :: message
integer                                 :: arraysize
integer                                 :: maxtry
integer                                 :: imin, imax
integer                                 :: error
   if(.not.allocated(list))then
      list=[character(len=max(len_trim(value),2)) :: ]
   endif
   arraysize=size(list)
   if(debug)write(stderr,*)'*locate_c* START ARRAYSIZE=',size(list)

   error=0
   if(arraysize.eq.0)then
      maxtry=0
      place=-1
   else
      maxtry=int(log(float(arraysize))/log(2.0)+1.0)
      place=(arraysize+1)/2
   endif
   imin=1
   imax=arraysize
   message=''

   LOOP: block
   do i=1,maxtry

      if(value.eq.list(PLACE))then
         exit LOOP
      else if(value.gt.list(place))then
         imax=place-1
      else
         imin=place+1
      endif

      if(imin.gt.imax)then
         place=-imin
         if(iabs(place).gt.arraysize)then ! ran off end of list. Where new value should go or an unsorted input array'
            exit LOOP
         endif
         exit LOOP
      endif

      place=(imax+imin)/2

      if(place.gt.arraysize.or.place.le.0)then
         message='*locate* error: search is out of bounds of list. Probably an unsorted input array'
         error=-1
         exit LOOP
      endif

   enddo
   message='*locate* exceeded allowed tries. Probably an unsorted input array'
   endblock LOOP
   if(present(ier))then
      ier=error
   else if(error.ne.0)then
      write(stderr,*)message//' VALUE=',trim(value)//' PLACE=',place
      stop 1
   endif
   if(present(errmsg))then
      errmsg=message
   endif
   if(debug)write(stderr,*)'*locate_c* END PLACE=',place,' ARRAYSIZE=',size(list),' LENGTH=',len(list)
end subroutine locate_c
!===================================================================================================================================
subroutine locate_d(list,value,place,ier,errmsg)

character(len=*),parameter::ident_6="&
&@(#)M_list::locate_d(3f): find PLACE in sorted doubleprecision array where VALUE can be found or should be placed"

! Assuming an array sorted in descending order
!
!  1. If it is not found report where it should be placed as a NEGATIVE index number.

doubleprecision,allocatable            :: list(:)
doubleprecision,intent(in)             :: value
integer,intent(out)                    :: place
integer,intent(out),optional           :: ier
character(len=*),intent(out),optional  :: errmsg

integer                                :: i
character(len=:),allocatable           :: message
integer                                :: arraysize
integer                                :: maxtry
integer                                :: imin, imax
integer                                :: error

   if(.not.allocated(list))then
      list=[doubleprecision :: ]
   endif
   arraysize=size(list)
   if(debug)write(stderr,*)'*locate_d* START ARRAYSIZE=',size(list)

   error=0
   if(arraysize.eq.0)then
      maxtry=0
      place=-1
   else
      maxtry=int(log(float(arraysize))/log(2.0)+1.0)
      place=(arraysize+1)/2
   endif
   imin=1
   imax=arraysize
   message=''

   LOOP: block
   do i=1,maxtry

      if(value.eq.list(PLACE))then
         exit LOOP
      else if(value.gt.list(place))then
         imax=place-1
      else
         imin=place+1
      endif

      if(imin.gt.imax)then
         place=-imin
         if(iabs(place).gt.arraysize)then ! ran off end of list. Where new value should go or an unsorted input array'
            exit LOOP
         endif
         exit LOOP
      endif

      place=(imax+imin)/2

      if(place.gt.arraysize.or.place.le.0)then
         message='*locate* error: search is out of bounds of list. Probably an unsorted input array'
         error=-1
         exit LOOP
      endif

   enddo
   message='*locate* exceeded allowed tries. Probably an unsorted input array'
   endblock LOOP
   if(present(ier))then
      ier=error
   else if(error.ne.0)then
      write(stderr,*)message//' VALUE=',value,' PLACE=',place
      stop 1
   endif
   if(present(errmsg))then
      errmsg=message
   endif
   if(debug)write(stderr,*)'*locate_d* END PLACE=',place,' ARRAYSIZE=',size(list)
end subroutine locate_d
!===================================================================================================================================
subroutine locate_r(list,value,place,ier,errmsg)

character(len=*),parameter::ident_7="&
&@(#)M_list::locate_r(3f): find PLACE in sorted real array where VALUE can be found or should be placed"

! Assuming an array sorted in descending order
!
!  1. If it is not found report where it should be placed as a NEGATIVE index number.

real,allocatable                       :: list(:)
real,intent(in)                        :: value
integer,intent(out)                    :: place
integer,intent(out),optional           :: ier
character(len=*),intent(out),optional  :: errmsg

integer                                :: i
character(len=:),allocatable           :: message
integer                                :: arraysize
integer                                :: maxtry
integer                                :: imin, imax
integer                                :: error

   if(.not.allocated(list))then
      list=[real :: ]
   endif
   arraysize=size(list)
   if(debug)write(stderr,*)'*locate_r* START ARRAYSIZE=',size(list)

   error=0
   if(arraysize.eq.0)then
      maxtry=0
      place=-1
   else
      maxtry=int(log(float(arraysize))/log(2.0)+1.0)
      place=(arraysize+1)/2
   endif
   imin=1
   imax=arraysize
   message=''

   LOOP: block
   do i=1,maxtry

      if(value.eq.list(PLACE))then
         exit LOOP
      else if(value.gt.list(place))then
         imax=place-1
      else
         imin=place+1
      endif

      if(imin.gt.imax)then
         place=-imin
         if(iabs(place).gt.arraysize)then ! ran off end of list. Where new value should go or an unsorted input array'
            exit LOOP
         endif
         exit LOOP
      endif

      place=(imax+imin)/2

      if(place.gt.arraysize.or.place.le.0)then
         message='*locate* error: search is out of bounds of list. Probably an unsorted input array'
         error=-1
         exit LOOP
      endif

   enddo
   message='*locate* exceeded allowed tries. Probably an unsorted input array'
   endblock LOOP
   if(present(ier))then
      ier=error
   else if(error.ne.0)then
      write(stderr,*)message//' VALUE=',value,' PLACE=',place
      stop 1
   endif
   if(present(errmsg))then
      errmsg=message
   endif
   if(debug)write(stderr,*)'*locate_r* END PLACE=',place,' ARRAYSIZE=',size(list)
end subroutine locate_r
!===================================================================================================================================
subroutine locate_i(list,value,place,ier,errmsg)

character(len=*),parameter::ident_8="&
&@(#)M_list::locate_i(3f): find PLACE in sorted integer array where VALUE can be found or should be placed"

! Assuming an array sorted in descending order
!
!  1. If it is not found report where it should be placed as a NEGATIVE index number.

integer,allocatable                    :: list(:)
integer,intent(in)                     :: value
integer,intent(out)                    :: place
integer,intent(out),optional           :: ier
character(len=*),intent(out),optional  :: errmsg

integer                                :: i
character(len=:),allocatable           :: message
integer                                :: arraysize
integer                                :: maxtry
integer                                :: imin, imax
integer                                :: error

   if(.not.allocated(list))then
      list=[integer :: ]
   endif
   arraysize=size(list)
   if(debug)write(stderr,*)'*locate_i* START ARRAYSIZE=',size(list)

   error=0
   if(arraysize.eq.0)then
      maxtry=0
      place=-1
   else
      maxtry=int(log(float(arraysize))/log(2.0)+1.0)
      place=(arraysize+1)/2
   endif
   imin=1
   imax=arraysize
   message=''

   LOOP: block
   do i=1,maxtry

      if(value.eq.list(PLACE))then
         exit LOOP
      else if(value.gt.list(place))then
         imax=place-1
      else
         imin=place+1
      endif

      if(imin.gt.imax)then
         place=-imin
         if(iabs(place).gt.arraysize)then ! ran off end of list. Where new value should go or an unsorted input array'
            exit LOOP
         endif
         exit LOOP
      endif

      place=(imax+imin)/2

      if(place.gt.arraysize.or.place.le.0)then
         message='*locate* error: search is out of bounds of list. Probably an unsorted input array'
         error=-1
         exit LOOP
      endif

   enddo
   message='*locate* exceeded allowed tries. Probably an unsorted input array'
   endblock LOOP
   if(present(ier))then
      ier=error
   else if(error.ne.0)then
      write(stderr,*)message//' VALUE=',value,' PLACE=',place
      stop 1
   endif
   if(present(errmsg))then
      errmsg=message
   endif
   if(debug)write(stderr,*)'*locate_i* END PLACE=',place,' ARRAYSIZE=',size(list)
end subroutine locate_i
!===================================================================================================================================
!()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()=
!===================================================================================================================================
subroutine remove_c(list,place)

character(len=*),parameter::ident_9="@(#)M_list::remove_c(3fp): remove string from allocatable string array at specified position"

character(len=:),allocatable :: list(:)
integer,intent(in)           :: place
integer                      :: ii, end
   if(debug) write(stderr,*)'*remove_c* START PLACE=',place,' ORIGINALSIZE=',size(list)
   if(.not.allocated(list))then
      list=[character(len=2) :: ]
   endif
   ii=len(list)
   end=size(list)
   if(place.le.0.or.place.gt.end)then                       ! index out of bounds of array
   elseif(place.eq.end)then                                 ! remove from array
      list=[character(len=ii) :: list(:place-1) ]
   else
      list=[character(len=ii) :: list(:place-1), list(place+1:) ]
   endif
   if(debug)write(stderr,*)'*remove_c* END PLACE=',place,' NEWSIZE=',size(list),' LENGTH=',len(list)
end subroutine remove_c
!===================================================================================================================================
subroutine remove_d(list,place)

character(len=*),parameter::ident_10="&
&@(#)M_list::remove_d(3fp): remove doubleprecision value from allocatable array at specified position"

doubleprecision,allocatable  :: list(:)
integer,intent(in)           :: place
integer                      :: end
   if(debug) write(stderr,*)'*remove_d* START PLACE=',place,' ORIGINALSIZE=',size(list)
   if(.not.allocated(list))then
           list=[doubleprecision :: ]
   endif
   end=size(list)
   if(place.le.0.or.place.gt.end)then                       ! index out of bounds of array
   elseif(place.eq.end)then                                 ! remove from array
      list=[ list(:place-1)]
   else
      list=[ list(:place-1), list(place+1:) ]
   endif
   if(debug)write(stderr,*)'*remove_d* END PLACE=',place,' NEWSIZE=',size(list)

end subroutine remove_d
!===================================================================================================================================
subroutine remove_r(list,place)

character(len=*),parameter::ident_11="@(#)M_list::remove_r(3fp): remove value from allocatable array at specified position"

real,allocatable    :: list(:)
integer,intent(in)  :: place
integer             :: end
   if(debug) write(stderr,*)'*remove_r* START PLACE=',place,' ORIGINALSIZE=',size(list)
   if(.not.allocated(list))then
      list=[real :: ]
   endif
   end=size(list)
   if(place.le.0.or.place.gt.end)then                       ! index out of bounds of array
   elseif(place.eq.end)then                                 ! remove from array
      list=[ list(:place-1)]
   else
      list=[ list(:place-1), list(place+1:) ]
   endif
   if(debug)write(stderr,*)'*remove_r* END PLACE=',place,' NEWSIZE=',size(list)

end subroutine remove_r
!===================================================================================================================================
subroutine remove_l(list,place)

character(len=*),parameter::ident_12="@(#)M_list::remove_l(3fp): remove value from allocatable array at specified position"

logical,allocatable    :: list(:)
integer,intent(in)     :: place
integer                :: end

   if(debug) write(stderr,*)'*remove_l* START PLACE=',place,' ORIGINALSIZE=',size(list)
   if(.not.allocated(list))then
      list=[logical :: ]
   endif
   end=size(list)
   if(place.le.0.or.place.gt.end)then                       ! index out of bounds of array
   elseif(place.eq.end)then                                 ! remove from array
      list=[ list(:place-1)]
   else
      list=[ list(:place-1), list(place+1:) ]
   endif
   if(debug)write(stderr,*)'*remove_l* END PLACE=',place,' NEWSIZE=',size(list)

end subroutine remove_l
!===================================================================================================================================
subroutine remove_i(list,place)

character(len=*),parameter::ident_13="@(#)M_list::remove_i(3fp): remove value from allocatable array at specified position"
integer,allocatable    :: list(:)
integer,intent(in)     :: place
integer                :: end

   if(debug) write(stderr,*)'*remove_i* START PLACE=',place,' ORIGINALSIZE=',size(list)
   if(.not.allocated(list))then
      list=[integer :: ]
   endif
   end=size(list)
   if(place.le.0.or.place.gt.end)then                       ! index out of bounds of array
   elseif(place.eq.end)then                                 ! remove from array
      list=[ list(:place-1)]
   else
      list=[ list(:place-1), list(place+1:) ]
   endif
   if(debug)write(stderr,*)'*remove_i* END PLACE=',place,' NEWSIZE=',size(list)

end subroutine remove_i
!===================================================================================================================================
!()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()=
!===================================================================================================================================
subroutine replace_c(list,value,place)

character(len=*),parameter::ident_14="@(#)M_list::replace_c(3fp): replace string in allocatable string array at specified position"

character(len=*),intent(in)  :: value
character(len=:),allocatable :: list(:)
character(len=:),allocatable :: kludge(:)
integer,intent(in)           :: place
integer                      :: ii
integer                      :: tlen
integer                      :: end
   if(debug) write(stderr,*)'*replace_c* START VALUE=',trim(value),' PLACE=',place,' ORIGINALSIZE=',size(list)
   if(.not.allocated(list))then
      list=[character(len=max(len_trim(value),2)) :: ]
   endif
   tlen=len_trim(value)
   end=size(list)
   if(place.lt.0.or.place.gt.end)then
           write(stderr,*)'*replace_c* error: index out of range. end=',end,' index=',place
   elseif(len_trim(value).le.len(list))then
      list(place)=value
   else  ! increase length of variable
      ii=max(tlen,len(list))
      kludge=[character(len=ii) :: list ]
      list=kludge
      list(place)=value
   endif
   if(debug)write(stderr,*)'*replace_c* END VALUE=',trim(value),' PLACE=',place,' NEWSIZE=',size(list),' LENGTH=',len(list)
end subroutine replace_c
!===================================================================================================================================
subroutine replace_d(list,value,place)

character(len=*),parameter::ident_15="&
&@(#)M_list::replace_d(3fp): place doubleprecision value into allocatable array at specified position"

doubleprecision,intent(in)   :: value
doubleprecision,allocatable  :: list(:)
integer,intent(in)           :: place
integer                      :: end
   if(debug) write(stderr,*)'*replace_d* START VALUE=',value,' PLACE=',place,' ORIGINALSIZE=',size(list)
   if(.not.allocated(list))then
           list=[doubleprecision :: ]
   endif
   end=size(list)
   if(end.eq.0)then                                          ! empty array
      list=[value]
   elseif(place.gt.0.and.place.le.end)then
      list(place)=value
   else                                                      ! put in middle of array
      write(stderr,*)'*replace_d* error: index out of range. end=',end,' index=',place
   endif
   if(debug)write(stderr,*)'*replace_d* END VALUE=',value,' PLACE=',place,' NEWSIZE=',size(list)
end subroutine replace_d
!===================================================================================================================================
subroutine replace_r(list,value,place)

character(len=*),parameter::ident_16="@(#)M_list::replace_r(3fp): place value into allocatable array at specified position"

real,intent(in)       :: value
real,allocatable      :: list(:)
integer,intent(in)    :: place
integer               :: end
   if(debug) write(stderr,*)'*replace_r* START REPLACE_R VALUE=',value,' PLACE=',place,' ORIGINALSIZE=',size(list)
   if(.not.allocated(list))then
      list=[real :: ]
   endif
   end=size(list)
   if(end.eq.0)then                                          ! empty array
      list=[value]
   elseif(place.gt.0.and.place.le.end)then
      list(place)=value
   else                                                      ! put in middle of array
      write(stderr,*)'*replace_r* error: index out of range. end=',end,' index=',place
   endif
   if(debug)write(stderr,*)'*replace_r* END REPLACE_R VALUE=',value,' PLACE=',place,' NEWSIZE=',size(list)
end subroutine replace_r
!===================================================================================================================================
subroutine replace_l(list,value,place)

character(len=*),parameter::ident_17="@(#)M_list::replace_l(3fp): place value into allocatable array at specified position"

logical,allocatable   :: list(:)
logical,intent(in)    :: value
integer,intent(in)    :: place
integer               :: end
   if(.not.allocated(list))then
      list=[logical :: ]
   endif
   end=size(list)
   if(debug)write(stderr,*)'*replace_l* START REPLACE_L VALUE=',value,' PLACE=',place,' ORIGINALSIZE=',size(list)
   if(end.eq.0)then                                          ! empty array
      list=[value]
   elseif(place.gt.0.and.place.le.end)then
      list(place)=value
   else                                                      ! put in middle of array
      write(stderr,*)'*replace_l* error: index out of range. end=',end,' index=',place
   endif
   if(debug)write(stderr,*)'*replace_l* END REPLACE_L VALUE=',value,' PLACE=',place,' NEWSIZE=',size(list)
end subroutine replace_l
!===================================================================================================================================
subroutine replace_i(list,value,place)

character(len=*),parameter::ident_18="@(#)M_list::replace_i(3fp): place value into allocatable array at specified position"

integer,intent(in)    :: value
integer,allocatable   :: list(:)
integer,intent(in)    :: place
integer               :: end
   if(.not.allocated(list))then
      list=[integer :: ]
   endif
   end=size(list)
   if(debug)write(stderr,*)'*replace_i* START VALUE=',value,' PLACE=',place,' ORIGINALSIZE=',size(list)
   if(end.eq.0)then                                          ! empty array
      list=[value]
   elseif(place.gt.0.and.place.le.end)then
      list(place)=value
   else                                                      ! put in middle of array
      write(stderr,*)'*replace_i* error: index out of range. end=',end,' index=',place
   endif
   if(debug)write(stderr,*)'*replace_i* END VALUE=',value,' PLACE=',place,' NEWSIZE=',size(list)
end subroutine replace_i
!===================================================================================================================================
!()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()=
!===================================================================================================================================
subroutine insert_c(list,value,place)

character(len=*),parameter::ident_19="@(#)M_list::insert_c(3fp): place string into allocatable string array at specified position"

character(len=*),intent(in)  :: value
character(len=:),allocatable :: list(:)
character(len=:),allocatable :: kludge(:)
integer,intent(in)           :: place
integer                      :: ii
integer                      :: end
   if(debug) write(stderr,*)'*insert_c* START VALUE=',trim(value),' PLACE=',place,' ORIGINALSIZE=',size(list)

   if(.not.allocated(list))then
      list=[character(len=max(len_trim(value),2)) :: ]
   endif

   ii=max(len_trim(value),len(list),2)
   end=size(list)

   if(end.eq.0)then                                          ! empty array
      list=[character(len=ii) :: value ]
   elseif(place.eq.1)then                                    ! put in front of array
      kludge=[character(len=ii) :: value, list]
      list=kludge
   elseif(place.gt.end)then                                  ! put at end of array
      kludge=[character(len=ii) :: list, value ]
      list=kludge
   elseif(place.ge.2.and.place.le.end)then                 ! put in middle of array
      kludge=[character(len=ii) :: list(:place-1), value,list(place:) ]
      list=kludge
   else                                                      ! index out of range
      write(stderr,*)'*insert_c* error: index out of range. end=',end,' index=',place,' value=',value
   endif

   if(debug)write(stderr,*)'*insert_c* END VALUE=',trim(value),' PLACE=',place,' NEWSIZE=',size(list)
end subroutine insert_c
!===================================================================================================================================
subroutine insert_r(list,value,place)

character(len=*),parameter::ident_20="@(#)M_list::insert_r(3fp): place real value into allocatable array at specified position"

real,intent(in)       :: value
real,allocatable      :: list(:)
integer,intent(in)    :: place
integer               :: end

   if(debug) write(stderr,*)'*insert_r* START VALUE=',value,' PLACE=',place,' ORIGINALSIZE=',size(list)
   if(.not.allocated(list))then
      list=[real :: ]
   endif

   end=size(list)
   if(end.eq.0)then                                          ! empty array
      list=[value]
   elseif(place.eq.1)then                                    ! put in front of array
      list=[value, list]
   elseif(place.gt.end)then                                  ! put at end of array
      list=[list, value ]
   elseif(place.ge.2.and.place.le.end)then                   ! put in middle of array
      list=[list(:place-1), value,list(place:) ]
   else                                                      ! index out of range
      write(stderr,*)'*insert_r* error: index out of range. end=',end,' index=',place,' value=',value
   endif

   if(debug)write(stderr,*)'*insert_r* END VALUE=',value,' PLACE=',place,' NEWSIZE=',size(list)
end subroutine insert_r
!===================================================================================================================================
subroutine insert_d(list,value,place)

character(len=*),parameter::ident_21="&
&@(#)M_list::insert_d(3fp): place doubleprecision value into allocatable array at specified position"

doubleprecision,intent(in)       :: value
doubleprecision,allocatable      :: list(:)
integer,intent(in)               :: place
integer                          :: end
   if(debug) write(stderr,*)'*insert_d* START VALUE=',value,' PLACE=',place,' ORIGINALSIZE=',size(list)
   if(.not.allocated(list))then
      list=[doubleprecision :: ]
   endif
   end=size(list)
   if(end.eq.0)then                                          ! empty array
      list=[value]
   elseif(place.eq.1)then                                    ! put in front of array
      list=[value, list]
   elseif(place.gt.end)then                                  ! put at end of array
      list=[list, value ]
   elseif(place.ge.2.and.place.le.end)then                 ! put in middle of array
      list=[list(:place-1), value,list(place:) ]
   else                                                      ! index out of range
      write(stderr,*)'*insert_d* error: index out of range. end=',end,' index=',place,' value=',value
   endif
   if(debug)write(stderr,*)'*insert_d* END VALUE=',value,' PLACE=',place,' NEWSIZE=',size(list)
end subroutine insert_d
!===================================================================================================================================
subroutine insert_l(list,value,place)

character(len=*),parameter::ident_22="@(#)M_list::insert_l(3fp): place value into allocatable array at specified position"

logical,allocatable   :: list(:)
logical,intent(in)    :: value
integer,intent(in)    :: place
integer               :: end
   if(.not.allocated(list))then
      list=[logical :: ]
   endif
   end=size(list)
   if(debug)write(stderr,*)'*insert_l* START VALUE=',value,' PLACE=',place,' ORIGINALSIZE=',size(list)
   if(end.eq.0)then                                          ! empty array
      list=[value]
   elseif(place.eq.1)then                                    ! put in front of array
      list=[value, list]
   elseif(place.gt.end)then                                  ! put at end of array
      list=[list, value ]
   elseif(place.ge.2.and.place.le.end)then                 ! put in middle of array
      list=[list(:place-1), value,list(place:) ]
   else                                                      ! index out of range
      write(stderr,*)'*insert_l* error: index out of range. end=',end,' index=',place,' value=',value
   endif

   if(debug)write(stderr,*)'*insert_l* END VALUE=',value,' PLACE=',place,' NEWSIZE=',size(list)
end subroutine insert_l
!===================================================================================================================================
subroutine insert_i(list,value,place)

character(len=*),parameter::ident_23="@(#)M_list::insert_i(3fp): place value into allocatable array at specified position"

integer,allocatable   :: list(:)
integer,intent(in)    :: value
integer,intent(in)    :: place
integer               :: end
   if(.not.allocated(list))then
      list=[integer :: ]
   endif
   end=size(list)
   if(debug)write(stderr,*)'*insert_i* START VALUE=',value,' PLACE=',place,' ORIGINALSIZE=',size(list)
   if(end.eq.0)then                                          ! empty array
      list=[value]
   elseif(place.eq.1)then                                    ! put in front of array
      list=[value, list]
   elseif(place.gt.end)then                                  ! put at end of array
      list=[list, value ]
   elseif(place.ge.2.and.place.le.end)then                 ! put in middle of array
      list=[list(:place-1), value,list(place:) ]
   else                                                      ! index out of range
      write(stderr,*)'*insert_i* error: index out of range. end=',end,' index=',place,' value=',value
   endif

   if(debug)write(stderr,*)'*insert_i* END VALUE=',value,' PLACE=',place,' NEWSIZE=',size(list)
end subroutine insert_i
!===================================================================================================================================
!()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()=
!===================================================================================================================================
subroutine dict_delete(self,key)

character(len=*),parameter::ident_24="@(#)M_list::dict_delete(3f): remove string from sorted allocatable string array if present"

class(dictionary),intent(inout) :: self
character(len=*),intent(in)     :: key
integer                         :: place

   call locate(self%key,key,place)
   if(place.ge.1)then
      call remove(self%key,place)
      call remove(self%value,place)
      call remove(self%count,place)
   endif

end subroutine dict_delete
!===================================================================================================================================
!()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()=
!===================================================================================================================================
function dict_get(self,key) result(value)

character(len=*),parameter::ident_25="@(#)M_list::dict_get(3f): get value of key-value pair in dictionary, given key"

class(dictionary)               :: self
character(len=*),intent(in)     :: key
character(len=:),allocatable    :: value
integer                         :: place
   call locate(self%key,key,place)
   if(place.lt.1)then
      value=''
   else
      value=self%value(place)(:self%count(place))
   endif
end function dict_get
!===================================================================================================================================
!()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()=
!===================================================================================================================================
subroutine dict_add(self,key,value)

character(len=*),parameter::ident_26="@(#)M_list::dict_add(3f): place key-value pair into dictionary, adding the key if required"

class(dictionary),intent(inout) :: self
character(len=*),intent(in)     :: key
character(len=*),intent(in)     :: value
integer                         :: place
integer                         :: place2
   call locate(self%key,key,place)
   if(place.lt.1)then
      place2=iabs(place)
      call insert( self%key,   key,             place2 )
      call insert( self%value, value,           place2 )
      call insert( self%count, len_trim(value), place2 )
   elseif(place.gt.0)then  ! replace instead of insert
      call insert( self%value, value,           place )
      call insert( self%count, len_trim(value), place )
   endif
end subroutine dict_add
!===================================================================================================================================
!()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()=
!===================================================================================================================================
! COPY OF M_STRINGS
!===================================================================================================================================
!()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()!
!===================================================================================================================================
pure elemental function isupper(ch) result(res)

character(len=*),parameter::ident_68="@(#)M_strings::isupper(3f): returns true if character is an uppercase letter (A-Z)"

character,intent(in) :: ch
logical              :: res
   select case(ch)
   case('A':'Z')
     res=.true.
   case default
     res=.false.
   end select
end function isupper
!===================================================================================================================================
!()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()!
!===================================================================================================================================
elemental pure function upper(str,begin,end) result (string)

character(len=*),parameter::ident_21="@(#)M_strings::upper(3f): Changes a string to uppercase"

character(*), intent(In)      :: str                 ! inpout string to convert to all uppercase
integer, intent(in), optional :: begin,end
character(len(str))           :: string              ! output string that contains no miniscule letters
integer                       :: i                   ! loop counter
integer                       :: ibegin,iend
   string = str                                      ! initialize output string to input string

   ibegin = 1
   if (present(begin))then
      ibegin = max(ibegin,begin)
   endif

   iend = len_trim(str)
   if (present(end))then
      iend= min(iend,end)
   endif

   do i = ibegin, iend                               ! step thru each letter in the string in specified range
       select case (str(i:i))
       case ('a':'z')                                ! located miniscule letter
          string(i:i) = char(iachar(str(i:i))-32)    ! change miniscule letter to uppercase
       end select
   end do

end function upper
!===================================================================================================================================
!()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()!
!===================================================================================================================================
elemental pure function lower(str,begin,end) result (string)

character(len=*),parameter::ident_22="@(#)M_strings::lower(3f): Changes a string to lowercase over specified range"

character(*), intent(In)     :: str
character(len(str))          :: string
integer,intent(in),optional  :: begin, end
integer                      :: i
integer                      :: ibegin, iend
   string = str

   ibegin = 1
   if (present(begin))then
      ibegin = max(ibegin,begin)
   endif

   iend = len_trim(str)
   if (present(end))then
      iend= min(iend,end)
   endif

   do i = ibegin, iend                               ! step thru each letter in the string in specified range
      select case (str(i:i))
      case ('A':'Z')
         string(i:i) = char(iachar(str(i:i))+32)     ! change letter to miniscule
      case default
      end select
   end do

end function lower
!===================================================================================================================================
!()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()!
!===================================================================================================================================
function merge_str(str1,str2,expr) result(strout)
! for some reason the MERGE(3f) intrinsic requires the strings it compares to be of equal length
! make an alias for MERGE(3f) that makes the lengths the same before doing the comparison by padding the shorter one with spaces

character(len=*),parameter::ident_37="@(#)M_strings::merge_str(3f): pads first and second arguments to MERGE(3f) to same length"

character(len=*),intent(in)     :: str1
character(len=*),intent(in)     :: str2
logical,intent(in)              :: expr
character(len=:),allocatable    :: strout
integer                         :: big
   big=max(len(str1),len(str2))
   strout=trim(merge(lenset(str1,big),lenset(str2,big),expr))
end function merge_str
!===================================================================================================================================
function quote(str,mode,clip) result (quoted_str)
character(len=*),intent(in)          :: str                ! the string to be quoted
character(len=*),optional,intent(in) :: mode
logical,optional,intent(in)          :: clip
character(len=:),allocatable         :: quoted_str

character(len=1),parameter           :: double_quote = '"'
character(len=20)                    :: local_mode
logical                              :: local_clip
!-----------------------------------------------------------------------------------------------------------------------------------
   local_mode=merge_str(mode,'DOUBLE',present(mode))
   if(merge(clip,.false.,present(clip)))then
      quoted_str=adjustl(str)
   else
      quoted_str=str
   endif
   select case(lower(local_mode))
   case('double')
      quoted_str=double_quote//trim(replace_str(quoted_str,'"','""'))//double_quote
   case('escape')
      quoted_str=double_quote//trim(replace_str(quoted_str,'"','\"'))//double_quote
   case default
      write(*,*)'*quote* ERROR: unknown quote mode ',local_mode
      quoted_str=str
   end select
!-----------------------------------------------------------------------------------------------------------------------------------
end function quote
!===================================================================================================================================
!()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()!
!===================================================================================================================================
function replace_str(targetline,old,new,ierr,cmd,range) result (newline)

character(len=*),parameter::ident_10="@(#)M_strings::replace(3f): Globally replace one substring for another in string"

!-----------------------------------------------------------------------------------------------------------------------------------
! parameters
character(len=*),intent(in)            :: targetline   ! input line to be changed
character(len=*),intent(in),optional   :: old          ! old substring to replace
character(len=*),intent(in),optional   :: new          ! new substring
integer,intent(out),optional           :: ierr         ! error code. if ierr = -1 bad directive, >=0 then ierr changes made
character(len=*),intent(in),optional   :: cmd          ! contains the instructions changing the string
integer,intent(in),optional            :: range(2)     ! start and end of which changes to make
!-----------------------------------------------------------------------------------------------------------------------------------
! returns
character(len=:),allocatable  :: newline               ! output string buffer
!-----------------------------------------------------------------------------------------------------------------------------------
! local
character(len=:),allocatable  :: new_local, old_local
integer                       :: icount,ichange,ier2
integer                       :: original_input_length
integer                       :: len_old, len_new
integer                       :: ladd
integer                       :: left_margin, right_margin
integer                       :: ind
integer                       :: ic
integer                       :: ichar
integer                       :: range_local(2)
!-----------------------------------------------------------------------------------------------------------------------------------
!  get old_local and new_local from cmd or old and new
   if(present(cmd))then
      call crack_cmd(cmd,old_local,new_local,ier2)
      if(ier2.ne.0)then
         newline=targetline  ! if no changes are made return original string on error
         if(present(ierr))ierr=ier2
         return
      endif
   elseif(present(old).and.present(new))then
      old_local=old
      new_local=new
   else
      newline=targetline  ! if no changes are made return original string on error
      write(*,*)'*replace* must specify OLD and NEW or CMD'
      return
   endif
!-----------------------------------------------------------------------------------------------------------------------------------
   icount=0                                            ! initialize error flag/change count
   ichange=0                                           ! initialize error flag/change count
   original_input_length=len_trim(targetline)          ! get non-blank length of input line
   len_old=len(old_local)                              ! length of old substring to be replaced
   len_new=len(new_local)                              ! length of new substring to replace old substring
   left_margin=1                                       ! left_margin is left margin of window to change
   right_margin=len(targetline)                        ! right_margin is right margin of window to change
   newline=''                                          ! begin with a blank line as output string
!-----------------------------------------------------------------------------------------------------------------------------------
   if(present(range))then
      range_local=range
   else
      range_local=[1,original_input_length]
   endif
!-----------------------------------------------------------------------------------------------------------------------------------
   if(len_old.eq.0)then                                ! c//new/ means insert new at beginning of line (or left margin)
      ichar=len_new + original_input_length
      if(len_new.gt.0)then
         newline=new_local(:len_new)//targetline(left_margin:original_input_length)
      else
         newline=targetline(left_margin:original_input_length)
      endif
      ichange=1                                        ! made one change. actually, c/// should maybe return 0
      if(present(ierr))ierr=ichange
      return
   endif
!-----------------------------------------------------------------------------------------------------------------------------------
   ichar=left_margin                                   ! place to put characters into output string
   ic=left_margin                                      ! place looking at in input string
   loop: do
      ind=index(targetline(ic:),old_local(:len_old))+ic-1 ! try finding start of OLD in remaining part of input in change window
      if(ind.eq.ic-1.or.ind.gt.right_margin)then          ! did not find old string or found old string past edit window
         exit loop                                        ! no more changes left to make
      endif
      icount=icount+1                                  ! found an old string to change, so increment count of change candidates
      if(ind.gt.ic)then                                ! if found old string past at current position in input string copy unchanged
         ladd=ind-ic                                   ! find length of character range to copy as-is from input to output
         newline=newline(:ichar-1)//targetline(ic:ind-1)
         ichar=ichar+ladd
      endif
      if(icount.ge.range_local(1).and.icount.le.range_local(2))then    ! check if this is an instance to change or keep
         ichange=ichange+1
         if(len_new.ne.0)then                                          ! put in new string
            newline=newline(:ichar-1)//new_local(:len_new)
            ichar=ichar+len_new
         endif
      else
         if(len_old.ne.0)then                                          ! put in copy of old string
            newline=newline(:ichar-1)//old_local(:len_old)
            ichar=ichar+len_old
         endif
      endif
      ic=ind+len_old
   enddo loop
!-----------------------------------------------------------------------------------------------------------------------------------
   select case (ichange)
   case (0)                                            ! there were no changes made to the window
      newline=targetline                               ! if no changes made output should be input
   case default
      if(ic.lt.len(targetline))then                    ! if there is more after last change on original line add it
         newline=newline(:ichar-1)//targetline(ic:max(ic,original_input_length))
      endif
   end select
   if(present(ierr))ierr=ichange
!-----------------------------------------------------------------------------------------------------------------------------------
end function replace_str
!===================================================================================================================================
!()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()!
!===================================================================================================================================
subroutine crack_cmd(cmd,old,new,ierr)
!-----------------------------------------------------------------------------------------------------------------------------------
character(len=*),intent(in)              :: cmd
character(len=:),allocatable,intent(out) :: old,new                ! scratch string buffers
integer                                  :: ierr
!-----------------------------------------------------------------------------------------------------------------------------------
character(len=1)                         :: delimiters
integer                                  :: itoken
integer,parameter                        :: id=2                   ! expected location of delimiter
logical                                  :: ifok
integer                                  :: lmax                   ! length of target string
integer                                  :: start_token,end_token
!-----------------------------------------------------------------------------------------------------------------------------------
   ierr=0
   old=''
   new=''
   lmax=len_trim(cmd)                       ! significant length of change directive

   if(lmax.ge.4)then                      ! strtok ignores blank tokens so look for special case where first token is really null
      delimiters=cmd(id:id)               ! find delimiter in expected location
      itoken=0                            ! initialize strtok(3f) procedure

      if(strtok(cmd(id:),itoken,start_token,end_token,delimiters)) then        ! find OLD string
         old=cmd(start_token+id-1:end_token+id-1)
      else
         old=''
      endif

      if(cmd(id:id).eq.cmd(id+1:id+1))then
         new=old
         old=''
      else                                                                     ! normal case
         ifok=strtok(cmd(id:),itoken,start_token,end_token,delimiters)         ! find NEW string
         if(end_token .eq. (len(cmd)-id+1) )end_token=len_trim(cmd(id:))       ! if missing ending delimiter
         new=cmd(start_token+id-1:min(end_token+id-1,lmax))
      endif
   else                                                                        ! command was two or less characters
      ierr=-1
      write(*,*)'*crack_cmd* incorrect change directive -too short'
   endif

end subroutine crack_cmd
!===================================================================================================================================
!()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()!
!===================================================================================================================================
FUNCTION strtok(source_string,itoken,token_start,token_end,delimiters) result(strtok_status)
! JSU- 20151030

character(len=*),parameter::ident_13="@(#)M_strings::strtok(3f): Tokenize a string"

character(len=*),intent(in)  :: source_string    ! Source string to tokenize.
character(len=*),intent(in)  :: delimiters       ! list of separator characters. May change between calls
integer,intent(inout)        :: itoken           ! token count since started
logical                      :: strtok_status    ! returned value
integer,intent(out)          :: token_start      ! beginning of token found if function result is .true.
integer,intent(inout)        :: token_end        ! end of token found if function result is .true.
integer,save                 :: isource_len
!----------------------------------------------------------------------------------------------------------------------------
!  calculate where token_start should start for this pass
   if(itoken.le.0)then                           ! this is assumed to be the first call
      token_start=1
   else                                          ! increment start to previous end + 1
      token_start=token_end+1
   endif
!----------------------------------------------------------------------------------------------------------------------------
   isource_len=len(source_string)                ! length of input string
!----------------------------------------------------------------------------------------------------------------------------
   if(token_start.gt.isource_len)then            ! user input error or at end of string
      token_end=isource_len                      ! assume end of token is end of string until proven otherwise so it is set
      strtok_status=.false.
      return
   endif
!----------------------------------------------------------------------------------------------------------------------------
   ! find beginning of token
   do while (token_start .le. isource_len)       ! step thru each character to find next delimiter, if any
      if(index(delimiters,source_string(token_start:token_start)) .ne. 0) then
         token_start = token_start + 1
      else
         exit
      endif
   enddo
!----------------------------------------------------------------------------------------------------------------------------
   token_end=token_start
   do while (token_end .le. isource_len-1)       ! step thru each character to find next delimiter, if any
      if(index(delimiters,source_string(token_end+1:token_end+1)) .ne. 0) then  ! found a delimiter in next character
         exit
      endif
      token_end = token_end + 1
   enddo
!----------------------------------------------------------------------------------------------------------------------------
   if (token_start .gt. isource_len) then        ! determine if finished
      strtok_status=.false.                      ! flag that input string has been completely processed
   else
      itoken=itoken+1                            ! increment count of tokens found
      strtok_status=.true.                       ! flag more tokens may remain
   endif
!----------------------------------------------------------------------------------------------------------------------------
end function strtok
!===================================================================================================================================
!()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()!
!===================================================================================================================================
function lenset(line,length) result(strout)

character(len=*),parameter::ident_36="@(#)M_strings::lenset(3f): return string trimmed or padded to specified length"

character(len=*),intent(in)  ::  line
integer,intent(in)           ::  length
character(len=length)        ::  strout
   strout=line
end function lenset
!===================================================================================================================================
!()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()!
!===================================================================================================================================
end module M_CLI
!===================================================================================================================================
!()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()()!
!===================================================================================================================================