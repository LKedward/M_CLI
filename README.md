# M_CLI.f90 and associated files

![parse](images/parse.png)

## NAME

### M_CLI - parse Unix-like command line arguments from Fortran

## DESCRIPTION

   This package is a self-contained version of one mode of the M_args(3f)
   module in the GPF (General Purpose Fortran) package that has been
   extracted for those just interested in a library to crack the command
   line. In the GPF package this library is intertwined with several other
   large modules.

## DOWNLOAD
   ```bash
       git clone https://github.com/urbanjost/M_CLI.git
       cd M_CLI/src
       # change Makefile if not using gfortran(1)
       make
   ```
   This will compile the M_CLI module and build all the example programs.
## SUPPORTS FPM (registered at the [fpm(1) registry](https://github.com/fortran-lang/fpm-registry) )

   Alternatively, download the github repository and build it with 
   fpm ( as described at [Fortran Package Manager](https://github.com/fortran-lang/fpm) )
   
   ```bash
        git clone https://github.com/urbanjost/M_CLI.git
        cd M_CLI
        fpm build
        fpm test
   ```
   
   or just list it as a dependency in your fpm.toml project file.
   
        [dependencies]
        M_CLI        = { git = "https://github.com/urbanjost/M_CLI.git" }

## EXAMPLE

**This is how the interface works --**
   
* Basically you define a NAMELIST group called ARGS that has the names of all your command line arguments.
* Next, pass in a string that looks like the command you would use to execute the program with all values specified.
* you read the output as the NAMELIST group ARGS with a fixed block of code (that could be in an INCLUDE file)
* Now call a routine to handle errors and help-related text
   
Now all the values in the NAMELIST should be updated using values from the
command line and ready to use.
   
- [commandline](md/commandline.md) parses the command line options
   
- [check_commandline](md/check_commandline.md) convenience
  routine for checking status of READ of NAMELIST group
   
This short program defines a command that can be called like
   
```bash
   ./show -x 10 -y -20 --point 10,20,30 --title 'plot of stuff' *.in
```

```fortran
   program show
   use M_CLI, only : commandline, check_commandline, files=>unnamed
   implicit none
   integer :: i
   
   !! DEFINE NAMELIST
   real               :: x, y, z             ; namelist /args/ x,y,z
   real               :: point(3)            ; namelist /args/ point
   character(len=80)  :: title               ; namelist /args/ title
   logical            :: l                   ; namelist /args/ l
   
   !! DEFINE COMMAND
   character(len=*),parameter :: cmd= &
      '-x 1 -y 2.0 -z 3.5e0 --point -1,-2,-3 --title "my title" -l F '
   
   !! THIS BLOCK DOES THE COMMAND LINE PARSING AND SHOULD NOT HAVE TO CHANGE
      COMMANDLIN : block
         character(len=255)           :: message
         character(len=:),allocatable :: readme
         integer                      :: ios
         readme=commandline(cmd)
         read(readme,nml=args,iostat=ios,iomsg=message) !! UPDATE NAMELIST VARIABLES
         call check_commandline(ios,message)     !! HANDLE ERRORS FROM NAMELIST READ AND --usage
      endblock COMMANDLIN
   
   !! USE THE VALUES IN YOUR PROGRAM.
      write(*,nml=args)
   
   !! OPTIONAL UNNAMED VALUES FROM COMMAND LINE
      if(size(files).gt.0)then
         write(*,'(a)')'files:'
         write(*,'(i6.6,3a)')(i,'[',files(i),']',i=1,size(files))
      endif
   
   end program show
```
   
There are several styles possible for defining the NAMELIST group as well as
options on whether to do the parsing in the main program or in a contained procedure..
   
- [demo1](PROGRAMS/demo1.f90) full usage 
- [demo2](PROGRAMS/demo2.f90) shows putting everything including **help** and **version** information into a contained procedure.
- [demo3](PROGRAMS/demo3.f90) example of **basic** use 
- [demo4](PROGRAMS/demo4.f90) using  **COMPLEX** values!
- [demo5](PROGRAMS/demo5.f90) demo2 with added example code for **interactively editing the NAMELIST group**
   
Please provide feedback on the
[wiki](https://github.com/urbanjost/M_CLI/wiki) or in the __issues__
section or star the repository if you use the module (or let me know
why not and let others know what you did use!).

## Other things to do with [NAMELIST](https://github.com/urbanjost/M_CLI/) )

   click on the link for some unusual things to do with NAMELIST,
   Capture and Replay unit testing, exposing variables for interactive
   editing ...

