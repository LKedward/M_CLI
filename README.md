
# M_CLI.f90 and associated files

## NAME

   M_CLI - parse Unix-like command line arguments from Fortran

## DESCRIPTION

This package is a self-contained version of one mode of the M_args(3f)
module in the GPF (General Purpose Fortran) package that has been
extracted for those just interested in a library to crack the command
line. In the GPF package this library is intertwined with several other
large modules.

    git clone https://github.com/urbanjost/M_CLI.git
    cd M_CLI/src
    # change Makefile if not using gfortran(1)
    make

This will compile the M_CLI module and build all the example programs.
It has only been tested using GNU Fortran (GCC) 8.3.0 at this point.
As there is some variability in how NAMELIST works I am very interested
in results using other compilers.

Basically you define a NAMELIST group called ARGS that has the names of
all your command line arguments.

Next, call a routine passing it a string that looks like the command
you would use to execute the program with all values specified.

you read the output as the NAMELIST group ARGS.

Now all the values in the namelist should be updated using values from the
command line and ready to use.

- [get_commandline](md/get_commandline.md) parses the command line options

- [print_dictionary](md/print_dictionary.md) is used to show the state
  of the parameters as part of handling errors

This short program defines a command that can be called like

   ./show -x 10 -y -20 -point 10,20,30 -title 'plot of stuff' *.in

```fortran
   program show
   use M_CLI
   implicit none
   integer                      :: i, ios
   character(len=255)           :: message
   character(len=:),allocatable :: readme

   !! DEFINE NAMELIST
   real               :: x, y, z       ; namelist /args/ x,y,z
   real               :: point(3)      ; namelist /args/ point
   character(len=80)  :: title         ; namelist /args/ title
   logical            :: help, version ; namelist /args/ help, version
   logical            :: l             ; namelist /args/ l
   !! DEFINE COMMAND PROTOTYPE
   character(len=*),parameter   :: cmd= &
   &' -x 1 -y 2.0 -z 3.5e0 --point -1,-2,-3 --title "my title" --help F --version F -l F'

   !! SET ALL DEFAULT VALUES AND THEN APPLY VALUES FROM COMMAND LINE
   readme=get_commandline(cmd)
   read(readme,nml=args,iostat=ios,iomsg=message) !! UPDATE NAMELIST VARIABLES
   if(ios.ne.0)then                               !! HANDLE ERRORS
      write(*,'("ERROR:",i0,1x,a)')ios, trim(message)
      call print_dictionary('OPTIONS:')
      stop 1
   endif

   !! USE THE VALUES IN YOUR PROGRAM.
   write(*,nml=args)  
   if(size(unnamed).gt.0)then
      write(*,'(a)')'files:'
      write(*,'(i6.6,3a)')(i,'[',unnamed(i),']',i=1,size(unnamed))
   endif

   end program show
```

There are several styles possible for defining the NAMELIST group as well as
options on whether to do the parsing in the main program or in a contained procedure..

- [demo1](src/PROGRAMS/demo1.f90) basic usage with checking defining the NAMELIST group 
                                  on the same line as the declarations of the variables
- [demo2](src/PROGRAMS/demo2.f90) shows putting everything including help and version
                                  information into a contained procedure
- [demo3](src/PROGRAMS/demo3.f90) is an example of use for a quick prototype.
