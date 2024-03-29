!===============================================================================
! CVS: $Id: dead.F90,v 1.1.1.1 2005/02/03 22:29:01 steder Exp $
! CVS: $Source: /home/cvsroot/steder/pyCPL/dead6/dead.F90,v $
! CVS: $Name:  $
!===============================================================================
!BOP ===========================================================================
!
! !MODULE: dead -- the main program
!
! !DESCRIPTION:
!    This is the dead main program
!
! !REMARKS:
!    This file provides a high-level, generic, dead component for use in CCSM
!
! !REVISION HISTORY:
!     2002-Jan-01 - T. Bettge -- first prototype
!
! !INTERFACE:  -----------------------------------------------------------------

#include <preproc.h>

program dead

! !USES:

!EOP

   implicit none

   !--- formats ---
   character(len=*), parameter :: F00 = "('(dead-main) ',8a)"
   character(len=*), parameter :: F90 = "('(dead-main) ',73('='))"
   character(len=*), parameter :: F91 = "('(dead-main) ',73('-'))"

!-------------------------------------------------------------------------------
!
!-------------------------------------------------------------------------------

   call dead_init()
   call dead_run()
   call dead_final()

end program dead

!===============================================================================
!BOP ===========================================================================
!
! !IROUTINE: dead_init - initialize a decomposition
!
! !DESCRIPTION:
!     initialize method for dead model
!
! !REVISION HISTORY:
!     2003-Apr-20 - T. Craig - subroutinize
!
! !INTERFACE: ------------------------------------------------------------------

subroutine dead_init()

! !USES:

   use cpl_interface_mod
   use cpl_fields_mod
   use cpl_contract_mod
   use cpl_control_mod
   use shr_const_mod
   use shr_timer_mod
   use shr_sys_mod
   use shr_msg_mod
   use shr_kind_mod
   use data_mod

   implicit none

   integer(SHR_KIND_IN)           :: inimask = 0       ! variable for inimask

   integer(SHR_KIND_IN)           :: ierr              ! error code
   integer(SHR_KIND_IN)           :: local_comm        ! local communicator
   integer(SHR_KIND_IN)           :: mype,totpe        ! pe info
   integer(SHR_KIND_IN)           :: npesx(max_con)    ! processor decomposition
   integer(SHR_KIND_IN)           :: npesy(max_con)    ! processor decomposition

   integer(SHR_KIND_IN)           :: i,j,n             ! local  i,j,n indices
   real(SHR_KIND_R8)              :: lat               ! latitude
   real(SHR_KIND_R8)              :: lon               ! longitude
   integer(SHR_KIND_IN)           :: nf                ! fields loop index
      
   !--- formats ---
   character(len=*), parameter :: F00 = "('(dead_init) ',8a)"
   character(len=*), parameter :: F90 = "('(dead_init) ',73('='))"
   character(len=*), parameter :: F91 = "('(dead_init) ',73('-'))"

!-------------------------------------------------------------------------------
!
!-------------------------------------------------------------------------------

   call shr_timer_init
   call shr_timer_get(timer01,'dead timer01, main loop')
   call shr_timer_get(timer02,'dead timer02, recv')
   call shr_timer_get(timer03,'dead timer03, recv-send')
   call shr_timer_get(timer04,'dead timer04, send')
   call shr_timer_get(timer05,'dead timer05, send-recv')

   cpl_control_infoDbug = dbug

   !----------------------------------------------------------------------------
   ! compile dead model as a particular component (kinda kludgy)
   !----------------------------------------------------------------------------
   ncomp = MODELNUMBER ! set this via cpp
   str = 'none'
   if (ncomp == 1) str = cpl_fields_atmname
   if (ncomp == 2) str = cpl_fields_lndname
   if (ncomp == 3) str = cpl_fields_icename
   if (ncomp == 4) str = cpl_fields_ocnname

   write(6,F90)
   write(6,F00) ' CCSM dead component, compiled as: ',str
   write(6,F90)
   call shr_sys_flush(6)

   !----------------------------------------------------------------------------
   ! chdir, reset stdin and stdout
   !----------------------------------------------------------------------------
   call shr_msg_stdio(trim(str))
   call shr_sys_flush(6)

   !----------------------------------------------------------------------------
   ! read the namelist input (used to configure model)
   !----------------------------------------------------------------------------
   myModelName    =  'none'
   nxg            =  -9999
   nyg            =  -9999
   nproc_x        =  -9999
   seg_len        =  -9999
   ncpl           =  -9999
   decomp_type    =  -9999
   simTime        =  -9999.

   read(5,*) myModelName
   read(5,*) nxg(1)
   read(5,*) nyg(1)
   read(5,*) decomp_type(1)
   read(5,*) nproc_x(1)
   read(5,*) seg_len(1)
   read(5,*) ncpl(1)
   read(5,*) simTime

   write(6,*)
   write(6,*) '         Model  :  ',myModelName
   write(6,*) '           NGX  :  ',nxg(1)
   write(6,*) '           NGY  :  ',nyg(1)
   write(6,*) ' Decomposition  :  ',decomp_type(1)
   write(6,*) ' Num pes in X   :  ',nproc_x(1),'  (type 3 only)'
   write(6,*) ' Segment Length :  ',seg_len(1),'  (type 4 only)'
   write(6,*) ' Cpl Comm Freq  :  ',ncpl(1)
   write(6,*) ' Sim Time Proxy :  ',simTime
   write(6,*)
   call shr_sys_flush(6)
   
   if ( myModelName /= str ) then
      write(6,F00) "ERROR: model compiled as ",trim(str)
      write(6,F00) "ERROR: namelist input is for ",trim(myModelName)
      call shr_sys_abort(trim(str)//" namelist input")
   end if

   !----------------------------------------------------------------------------
   ! lnd component also needs runoff domain info
   !----------------------------------------------------------------------------
   if (myModelName == cpl_fields_lndname) then
      read(5,*) myModelName
      read(5,*) nxg(2)
      read(5,*) nyg(2)
      read(5,*) decomp_type(2)
      read(5,*) nproc_x(2)
      read(5,*) seg_len(2)
      read(5,*) ncpl(2)
      read(5,*) simTime

      write(6,*)
      write(6,*) '         Model  :  ',myModelName
      write(6,*) '           NGX  :  ',nxg(2)
      write(6,*) '           NGY  :  ',nyg(2)
      write(6,*) ' Decomposition  :  ',decomp_type(2)
      write(6,*) ' Num pes in X   :  ',nproc_x(2),'  (type 3 only)'
      write(6,*) ' Segment Length :  ',seg_len(2),'  (type 4 only)'
      write(6,*) ' Cpl Comm Freq  :  ',ncpl(2)
      write(6,*) ' Sim Time Proxy :  ',simTime
      write(6,*)
      call shr_sys_flush(6)
   endif

   ncpl_v1 = 0
   do n = 1,max_con
      if (ncpl(n) /= -9999) then
         if (mod(ncpl(1),ncpl(n)) /= 0) then
            write(6,*) 'ERROR in coupling frequency ',n,ncpl(n),ncpl(1)
            call shr_sys_abort('dead.F90, coupling freq')
         endif
         ncpl_v1(n) = ncpl(1)/ncpl(n)
      endif
   enddo

   !----------------------------------------------------------------------------
   ! initialize local MPH & MPI 
   !----------------------------------------------------------------------------
   call cpl_interface_init(myModelName,local_comm)

   !----------------------------------------------------------------------------
   ! configure dead component appropriately wrt component type
   !----------------------------------------------------------------------------
   if (myModelName == cpl_fields_atmname) then
      fields_m2c_total = cpl_fields_a2c_total
      fields_m2c_list  = cpl_fields_a2c_fields
      fields_c2m_total = cpl_fields_c2a_total
      fields_c2m_list  = cpl_fields_c2a_fields
      ncomp               = 1
   else if (myModelName == cpl_fields_icename) then
      fields_m2c_total = cpl_fields_i2c_total
      fields_m2c_list  = cpl_fields_i2c_fields
      fields_c2m_total = cpl_fields_c2i_total
      fields_c2m_list  = cpl_fields_c2i_fields
      ncomp               = 2
   else if (myModelName == cpl_fields_lndname) then
      fields_m2c_total = cpl_fields_l2c_total
      fields_m2c_list  = cpl_fields_l2c_fields
      fields_c2m_total = cpl_fields_c2l_total
      fields_c2m_list  = cpl_fields_c2l_fields
      ncomp               = 3
   else if (myModelName == cpl_fields_ocnname) then
      fields_m2c_total = cpl_fields_o2c_total
      fields_m2c_list  = cpl_fields_o2c_fields
      fields_c2m_total = cpl_fields_c2o_total
      fields_c2m_list  = cpl_fields_c2o_fields
      ncomp               = 4
   else
      write(6,*) '<ERROR> myModelName = ',myModelName 
   endif

   !----------------------------------------------------------------------------
   ! decompose model
   !----------------------------------------------------------------------------
   call MPI_COMM_RANK(local_comm,mype ,ierr)
   call MPI_COMM_SIZE(local_comm,totpe,ierr)

   call set_decomp(decomp_type,nxg(1),nyg(1),totpe,seg_len(1),nproc_x(1), &
                   nx(1),ny(1),npesx(1),npesy(1))

   allocate(gbuf(nx(1)*ny(1),cpl_fields_grid_total))
   allocate(sbuf(nx(1)*ny(1),fields_m2c_total))
   allocate(rbuf(nx(1)*ny(1),fields_c2m_total))
   allocate(fields_m2c(nx(1),ny(1),fields_m2c_total) )
   allocate(fields_c2m(nx(1),ny(1),fields_c2m_total) )

   call set_gridbufs(decomp_type,nxg(1),nyg(1),nx(1),ny(1), &
                     npesx(1),npesy(1),mype,isbuf,gbuf)

   isbuf(cpl_fields_ibuf_ncpl)    = ncpl(1) ! coupling frequency
   isbuf(cpl_fields_ibuf_dead)    = 1       ! tell cpl6 this is a dead model
   isbuf(cpl_fields_ibuf_userest) = 1       ! tell cpl6 to use my IC data

   if (myModelName == cpl_fields_lndname) then
      inimask = 1
      isbuf(cpl_fields_ibuf_inimask) = inimask ! special mask initialization OFF
      write(6,*) trim(myModelName),' recv message for grid '
      call cpl_interface_contractInit(contractR(2),myModelName, &
        cpl_fields_cplname,cpl_fields_c2lg_fields,isbuf,gbuf)
      allocate(rbuf_g(nx(1)*ny(1),cpl_fields_c2lg_total))
      call cpl_interface_contractRecv(cpl_fields_cplname,contractR(2), &
                                      irbuf_g,rbuf_g)
      deallocate(rbuf_g)
   endif

   call cpl_interface_contractInit(contractS(1),myModelName,cpl_fields_cplname, &
        fields_m2c_list,isbuf,gbuf)
   call cpl_interface_contractInit(contractR(1),myModelName,cpl_fields_cplname, &
        fields_c2m_list,isbuf,gbuf)

   !----------------------------------------------------------------------------
   ! runoff initialization
   !----------------------------------------------------------------------------
   if (myModelName == cpl_fields_lndname) then
      fields_r2c_total = cpl_fields_r2c_total
      fields_r2c_list  = cpl_fields_r2c_fields
      call set_decomp(decomp_type(2),nxg(2),nyg(2),totpe,seg_len(2),nproc_x(2), &
                      nx(2),ny(2),npesx(2),npesy(2))

      allocate(gbuf_r(nx(2)*ny(2),cpl_fields_grid_total))
      allocate(sbuf_r(nx(2)*ny(2),fields_r2c_total))
      allocate(fields_r2c(nx(2),ny(2),fields_r2c_total) )
 
      call set_gridbufs(decomp_type(2),nxg(2),nyg(2),nx(2),ny(2), &
                        npesx(2),npesy(2),mype,isbuf_r,gbuf_r)
      isbuf_r(cpl_fields_ibuf_ncpl)=ncpl(2)

      ! tell cpl6 this is a dead model
      isbuf_r(cpl_fields_ibuf_dead) = 1

      call cpl_interface_contractInit(contractS(2),myModelName, &
        cpl_fields_cplname,fields_r2c_list,isbuf_r,gbuf_r)
   endif

   !----------------------------------------------------------------------------
   !  get initial message from coupler with cday, etc.
   !----------------------------------------------------------------------------
   call cpl_interface_infobufRecv(cpl_fields_cplname,irbuf)
   dbug = max(dbug,irbuf(cpl_fields_ibuf_infobug))
   cpl_control_infoDbug = dbug

   !----------------------------------------------------------------------------
   ! initial send to cpl, gives cpl IC data 
   !----------------------------------------------------------------------------
   do nf=1,fields_m2c_total
   do j=1,ny(1)
   do i=1,nx(1)
      !        value function of model,field,lat,lon
      !        notes:  amplitude is (nf*100)
      !                offset from zero is (ncomp*10)
      !                phase shift is 60 deg (pi/3)
      n = (j-1)*nx(1) + i      ! local 1d index
      lon = gbuf(n,cpl_fields_grid_lon)
      lat = gbuf(n,cpl_fields_grid_lat)
      fields_m2c(i,j,nf) = (nf*100)                        &
             *  cos (SHR_CONST_PI*lat/180.)                &
             *  sin((SHR_CONST_PI*lon/180.)                &
             - (ncomp-1)*(SHR_CONST_PI/3.0)) + (ncomp*10.0)
   enddo
   enddo
   enddo

   do nf=1,fields_m2c_total
   n=0
   do j=1,ny(1)
   do i=1,nx(1)
      n=n+1
      sbuf(n,nf) = fields_m2c(i,j,nf)
   enddo
   enddo
   enddo
   call cpl_interface_contractSend(cpl_fields_cplname,contractS(1),isbuf,sbuf)
      
   !----------------------------------------------------------------------------
   ! initial runoff send
   !----------------------------------------------------------------------------
   if (myModelName == cpl_fields_lndname) then
      !--- example of packing the contract in the model, rather than interface
      contractS(2)%bundle%data%rattr(1:fields_r2c_total,1:nx(2)*ny(2)) = 0.
      call cpl_interface_contractSend(cpl_fields_cplname,contractS(2),isbuf_r)
   endif

end subroutine dead_init

!===============================================================================
!BOP ===========================================================================
!
! !IROUTINE: dead_run
!
! !DESCRIPTION:
!     run method for dead model
!
! !REVISION HISTORY:
!     2003-Apr-20 - T. Craig - subroutinize
!
! !INTERFACE: ------------------------------------------------------------------

subroutine dead_run()

! !USES:

   use cpl_interface_mod
   use cpl_fields_mod
   use cpl_contract_mod
   use cpl_control_mod
   use shr_const_mod
   use shr_timer_mod
   use shr_sys_mod
   use shr_msg_mod
   use shr_kind_mod
   use data_mod

   implicit none

   integer(SHR_KIND_IN)           :: n1,n2             ! main loop counters
   integer(SHR_KIND_IN)           :: i,j,n             ! local  i,j,n indices
   real(SHR_KIND_R8)              :: lat               ! latitude
   real(SHR_KIND_R8)              :: lon               ! longitude
   integer(SHR_KIND_IN)           :: nf                ! fields loop index

   !--- formats ---
   character(len=*), parameter :: F00 = "('(dead_run) ',8a)"
   character(len=*), parameter :: F90 = "('(dead_run) ',73('='))"
   character(len=*), parameter :: F91 = "('(dead_run) ',73('-'))"

!-------------------------------------------------------------------------------
!
!-------------------------------------------------------------------------------

   !----------------------------------------------------------------------------
   ! main integration loop: repeat until cpl says stop
   !----------------------------------------------------------------------------
   call shr_timer_start(timer01)
   write(6,F91) 
   write(6,F00) trim(myModelName),': begining of main integration loop'
   write(6,F91) 
   n1=0 ! "outer loop" index
   loop: do
      if (dbug >= 3) write(6,*) myModelName,'TOP OF OUTER LOOP '
      n1=n1+1
      do n2=1,ncpl(1)
         call shr_timer_start(timer02)
         if (dbug >= 3) write(6,*) trim(myModelName),' RECV'
         call cpl_interface_contractRecv(cpl_fields_cplname,contractR(1), &
                                         irbuf,rbuf)
         call shr_timer_stop(timer02)
         call shr_timer_start(timer03)
         if (irbuf(cpl_fields_ibuf_stopnow) /= 0) then
            write(6,*) myModelName,'CPL SAYS STOP NOW'
            exit loop
         end if


         isbuf(cpl_fields_ibuf_cDate) = irbuf(cpl_fields_ibuf_cDate)
         isbuf(cpl_fields_ibuf_sec)   = irbuf(cpl_fields_ibuf_sec)

         do nf=1,fields_c2m_total
            n=0
            do j=1,ny(1)
            do i=1,nx(1)
               n=n+1
               fields_c2m(i,j,nf) = rbuf(n,nf)
            enddo
            enddo
         enddo

         do nf=1,fields_m2c_total
         do j=1,ny(1)
         do i=1,nx(1)
!           value function of model,field,lat,lon
!           notes:  amplitude is (nf*100)
!                    offset from zero is (ncomp*10)
!                    phase shift is 60 deg (pi/3)
            n = (j-1)*nx(1) + i      ! local 1d index
            lon = gbuf(n,cpl_fields_grid_lon)
            lat = gbuf(n,cpl_fields_grid_lat)
            fields_m2c(i,j,nf) = (nf*100)                                &
                               *  cos (SHR_CONST_PI*lat/180.)            &
                               *  sin((SHR_CONST_PI*lon/180.)            &
                               - (ncomp-1)*(SHR_CONST_PI/3.0)) + (ncomp*10.0)
         enddo
         enddo
         enddo

         call shr_timer_sleep(simTime)

         do nf=1,fields_m2c_total
            n=0
            do j=1,ny(1)
            do i=1,nx(1)
               n=n+1
               sbuf(n,nf) = fields_m2c(i,j,nf)
            enddo
            enddo
         enddo

         call shr_timer_stop(timer03)
         call shr_timer_start(timer04)

         if (dbug >= 3) write(6,*) trim(myModelName),': SEND'
         call cpl_interface_contractSend(cpl_fields_cplname,contractS(1),isbuf,sbuf)

         !--------------------------------------------------------------
         ! runoff send, when it's time
         !--------------------------------------------------------------
         if (myModelName == cpl_fields_lndname) then
             if (mod(n2,ncpl_v1(2)) == 0) then
                if (dbug >= 3) write(6,*) trim(myModelName),': SEND runoff'
                isbuf_r(cpl_fields_ibuf_cDate) = irbuf(cpl_fields_ibuf_cDate)
                isbuf_r(cpl_fields_ibuf_sec)   = irbuf(cpl_fields_ibuf_sec)
                sbuf_r(:,:) = float(n2)
                call cpl_interface_contractSend(cpl_fields_cplname,contractS(2), &
                                                isbuf_r,sbuf_r)
             endif
         endif
         call shr_timer_stop(timer04)
         call shr_timer_start(timer05)
         call shr_timer_stop(timer05)
      enddo
   enddo loop
   call shr_timer_stop(timer01)

end subroutine dead_run

!===============================================================================
!BOP ===========================================================================
!
! !IROUTINE: dead_final
!
! !DESCRIPTION:
!     finalize method for dead model
!
! !REVISION HISTORY:
!     2003-Apr-20 - T. Craig - subroutinize
!
! !INTERFACE: ------------------------------------------------------------------

subroutine dead_final()

! !USES:
   use cpl_interface_mod
   use shr_timer_mod
   use data_mod

   implicit none

   !--- formats ---
   character(len=*), parameter :: F00 = "('(dead_final) ',8a)"
   character(len=*), parameter :: F90 = "('(dead_final) ',73('='))"
   character(len=*), parameter :: F91 = "('(dead_final) ',73('-'))"

!-------------------------------------------------------------------------------
!
!-------------------------------------------------------------------------------

   !----------------------------------------------------------------------------
   ! finalize
   !----------------------------------------------------------------------------
   write(6,F91) 
   write(6,F00) trim(myModelName),': end of main integration loop'
   write(6,F91) 
   call shr_timer_print_all
   call cpl_interface_finalize(myModelName)

end subroutine dead_final

!===============================================================================
!BOP ===========================================================================
!
! !IROUTINE: set_decomp - initialize a decomposition
!
! !DESCRIPTION:
!     initialize decomposition parameters
!
! !REVISION HISTORY:
!     2002-Sep-10 - T. Craig - created subroutine based on T. Bettge's
!          implementation in main program.
!
! !INTERFACE: ------------------------------------------------------------------

subroutine set_decomp(decomp_type,nxg,nyg,totpe,seg_len,nproc_x,nx,ny,npesx,npesy)

! !USES:

   use shr_sys_mod
   use shr_kind_mod

   implicit none

! !INPUT/OUTPUT PARAMETERS:

   integer(SHR_KIND_IN),intent(in) :: decomp_type     ! 1=(1d lat) 2=(1d lon), 
                                         ! 3=(2d, nproc_x) 4=(seg_len)
   integer(SHR_KIND_IN),intent(in) :: nxg,nyg         ! global grid sizes
   integer(SHR_KIND_IN),intent(in) :: totpe           ! total number of pes
   integer(SHR_KIND_IN),intent(in) :: seg_len         ! segment length (for type 4)
   integer(SHR_KIND_IN),intent(in) :: nproc_x         ! number of pe in x (for type 3)
   integer(SHR_KIND_IN),intent(out):: nx,ny           ! local grid sizes
   integer(SHR_KIND_IN),intent(out):: npesx,npesy     ! global pe decomposition

!EOP

   !--- local ---
   integer(SHR_KIND_IN)            :: ierr            ! error code

!-------------------------------------------------------------------------------
!
!-------------------------------------------------------------------------------

   if (decomp_type == 1) then              ! change this to "case" structure
      !-------------------------------------------------------------------------
      ! type 1 1d decomp by lat, with equal chunks
      !-------------------------------------------------------------------------
      npesx=1         
      npesy=totpe    
      nx=nxg
      ny=nyg/npesy
      if ( ny*npesy /= nyg) then
         write(6,*) 'ERROR: uneven decomposition'
         call shr_sys_abort('dead.F90, decomp')
      end if
   else if (decomp_type == 2) then
      !-------------------------------------------------------------------------
      ! type 2 is 1d decomp by lon, with equal chunks
      !-------------------------------------------------------------------------
      npesx=totpe          
      npesy=1
      nx=nxg/npesx
      ny=nyg
      if ( nx*npesx /= nxg) then
         write(6,*) 'ERROR: uneven decomposition'
         call shr_sys_abort('dead.F90, decomp')
      end if
   else if (decomp_type == 3) then  
      !-------------------------------------------------------------------------
      ! type 3 is 2d decomp, with equal chunks
      !-------------------------------------------------------------------------
      if ( nproc_x <= 0 ) then 
         write(6,*) 'ERROR: with decomp_type of 3, nproc_x must be specified'
         call shr_sys_abort('dead.F90, decomp')
      endif
      npesx=nproc_x
      npesy=totpe/npesx
      nx=nxg/npesx
      ny=nyg/npesy
      if ( nx*npesx /= nxg) then
         write(6,*) 'ERROR: uneven decomposition'
         call shr_sys_abort('dead.F90, decomp')
      end if
      if ( ny*npesy /= nyg) then
         write(6,*) 'ERROR: uneven decomposition'
         call shr_sys_abort('dead.F90, decomp')
      end if
   else if (decomp_type == 4) then 
      !-------------------------------------------------------------------------
      ! type 4 general segment decomp
      !-------------------------------------------------------------------------
      write(6,*) 'ERROR:  decomp_type 4 not yet implemented'
      call shr_sys_abort('dead.F90, decomp_type 4')
      if ( seg_len <= 0 ) then        !  with equal lengths
         write(6,*) 'ERROR: with decomp_type of 4, seg_len must be specified'
         call shr_sys_abort('dead.F90, seg_len')
      endif
      ! Notes:
      !    Here the concept of nx and ny are logically changed:
      !        a segment is defined as the set of points all belonging to a pe
      !        seg_len is number of consecutive points belonging to
      !          current pe (might be mis-named) 
      !        nx is always (nxg*nyg)/totpe
      !        ny is always 1
      nx=nxg*nyg/totpe
      ny=1
      if ( (nx*totpe) /= (nxg*nyg) ) then
         write(6,*) 'ERROR: uneven decomposition'
         call shr_sys_abort('dead.F90, decomp')
      end if
   else 
      !-------------------------------------------------------------------------
      ! invalid decomposition type
      !-------------------------------------------------------------------------
      write(6,*) 'ERROR: invalid decomp_type = ',decomp_type
      call shr_sys_abort('dead.F90, decomp_type')
   endif

end subroutine set_decomp

!===============================================================================
!BOP ===========================================================================
!
! !IROUTINE: set_gridbufs - setup ibuf and buf for contract initialization
!
! !DESCRIPTION:
!     This sets up some defaults.  The user may want to overwrite some
!     of these fields in the main program after initialization in complete.
!
! !REVISION HISTORY:
!     2002-Sep-10 - T. Craig - created subroutine based on T. Bettge's
!          implementation in main program.
!
! !INTERFACE: ------------------------------------------------------------------

subroutine set_gridbufs(decomp_type,nxg,nyg,nx,ny,npesx,npesy,mype,isbuf,sbuf)

! !USES:

   use cpl_fields_mod
   use shr_sys_mod
   use shr_kind_mod

   implicit none

! !INPUT/OUTPUT PARAMETERS:

   integer(SHR_KIND_IN),intent(in)    :: decomp_type  ! 1=(1d lat) 2=(1d lon), 
                                         ! 3=(2d, nproc_x) 4=(seg_len)
   integer(SHR_KIND_IN),intent(in)    :: nxg,nyg      ! global grid sizes
   integer(SHR_KIND_IN),intent(in)    :: nx,ny        ! local grid sizes
   integer(SHR_KIND_IN),intent(in)    :: npesx,npesy  ! global pe decomposition
   integer(SHR_KIND_IN),intent(in)    :: mype         ! my pe number
   integer(SHR_KIND_IN),intent(inout) :: isbuf(cpl_fields_ibuf_total) ! info-buffer to send
   real(SHR_KIND_R8)   ,intent(inout) :: sbuf(nx*ny,cpl_fields_grid_total)    ! grid data buffer

!EOP

   !--- local ---
   integer(SHR_KIND_IN)            :: i,j,ig,jg,n,ng  ! indices

!-------------------------------------------------------------------------------
!
!-------------------------------------------------------------------------------

   isbuf=0
   isbuf(cpl_fields_ibuf_gsize  )=nxg*nyg
   isbuf(cpl_fields_ibuf_lsize  )=nx*ny
   isbuf(cpl_fields_ibuf_gisize )=nxg
   isbuf(cpl_fields_ibuf_gjsize )=nyg
   isbuf(cpl_fields_ibuf_nfields)=cpl_fields_grid_total

   sbuf = -888.0

   !---     grid composed, based upon decomp type (can be generalized)
   !---    ===> generalize the grid composer based upon even lat/lon

   n=0
   do j=1,ny                    ! local  j index
   do i=1,nx                    ! local  i index
      n  = n+1                  ! local  n index (vector index)
      if (decomp_type == 1) then
          ig = i                ! global i index
          jg = j + mype*ny      ! global j index
      endif
      if (decomp_type == 2) then
          ig = i + mype*nx      ! global i index
          jg = j                ! global j index
      endif
      if (decomp_type == 3) then
          ig=mod(mype,npesx)*nx+i  !global i index
          jg=(mype/npesx)*ny+j     !global j index
      endif
      ng = (jg-1)*nxg + ig      ! global n index (vector index)
      sbuf(n,cpl_fields_grid_lon  ) =         (ig-1)*360.0/(nxg)
      sbuf(n,cpl_fields_grid_lat  ) = -90.0 + (jg-1)*180.0/(nyg-1)
      sbuf(n,cpl_fields_grid_index) = ng
   enddo
   enddo

end subroutine set_gridbufs
!===============================================================================

