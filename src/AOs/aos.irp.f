 BEGIN_PROVIDER [ integer, ao_num ]
&BEGIN_PROVIDER [ integer, ao_num_align ]
 implicit none

 BEGIN_DOC
! Number of atomic orbitals
 END_DOC

 ao_num = -1
 PROVIDE ezfio_filename
 call ezfio_get_ao_basis_ao_num(ao_num)
 if (ao_num <= 0) then
   stop 'Number of contracted gaussians should be > 0'
 endif
 integer :: align_double
 ao_num_align = align_double(ao_num)
END_PROVIDER

 BEGIN_PROVIDER [ integer, ao_power, (ao_num_align,3) ]
&BEGIN_PROVIDER [ double precision, ao_expo, (ao_num_align,ao_prim_num_max) ]
&BEGIN_PROVIDER [ double precision, ao_coef, (ao_num_align,ao_prim_num_max) ]
 implicit none

 BEGIN_DOC
! Coefficients, exponents and powers of x,y and z
! ao_coef(i,j) = coefficient of the jth primitive on the ith ao
 END_DOC
 PROVIDE ezfio_filename

 double precision, allocatable :: buffer(:,:)
 allocate ( buffer(ao_num,ao_prim_num_max) )
 integer :: ibuffer(ao_num,3)
 integer :: i,j,k
 ibuffer = 0
 call ezfio_get_ao_basis_ao_power(ibuffer)
 ao_power = 0
 do j = 1, 3
  do i = 1, ao_num
   ao_power(i,j) = ibuffer(i,j)
  enddo
 enddo
 ao_expo  = 0.d0
 buffer = 0.d0
 call ezfio_get_ao_basis_ao_expo(buffer)
 do j = 1, ao_prim_num_max
  do i = 1, ao_num
   ao_expo(i,j) = buffer(i,j)
  enddo
 enddo
 ao_coef  = 0.d0
 buffer = 0.d0
 call ezfio_get_ao_basis_ao_coef(buffer)
 do j = 1, ao_prim_num_max
  do i = 1, ao_num
   ao_coef(i,j) = buffer(i,j)
  enddo
 enddo
 deallocate(buffer)

! Normalization of the AO coefficients
! ------------------------------------
 double precision :: norm, norm2,overlap_x,overlap_y,overlap_z,C_A(3)
 integer :: l, powA(3), nz
 nz=100
 C_A(1) = 0.d0
 C_A(2) = 0.d0
 C_A(3) = 0.d0
 do i=1,ao_num
  powA(1) = ao_power(i,1)
  powA(2) = ao_power(i,2)
  powA(3) = ao_power(i,3)
  do j=1,ao_prim_num(i)
   call overlap_gaussian_xyz(C_A,C_A,ao_expo(i,j),ao_expo(i,j),powA,powA,overlap_x,overlap_y,overlap_z,norm,nz)
   ao_coef(i,j) = ao_coef(i,j)/sqrt(norm)
  enddo
 enddo

 ! Sorting of the exponents for efficient integral calculations
 integer :: iorder(ao_prim_num_max)
 double precision :: d(ao_prim_num_max,2)
 do i=1,ao_num
  do j=1,ao_prim_num(i)
   iorder(j) = j
   d(j,1) = ao_expo(i,j)
   d(j,2) = ao_coef(i,j)
  enddo
  call dsort(d(1,1),iorder,ao_prim_num(i))
  call dset_order(d(1,2),iorder,ao_prim_num(i))
  do j=1,ao_prim_num(i)
   ao_expo(i,j) = d(j,1)
   ao_coef(i,j) = d(j,2)
  enddo
 enddo
END_PROVIDER

BEGIN_PROVIDER [ double precision, ao_overlap, (ao_num_align,ao_num) ]
 implicit none
 BEGIN_DOC
! matrix of the overlap for tha AOs 
! S(i,j) = overlap between the ith and the jth atomic basis function
 END_DOC
 integer :: i,j,k,l,nz,num_i,num_j,powA(3),powB(3)
 double precision :: accu,overlap_x,overlap_y,overlap_z,A_center(3),B_center(3),norm
 nz=100
 do i = 1, ao_num 
  num_i = ao_nucl(i)
  powA(1) = ao_power(i,1)
  powA(2) = ao_power(i,2)
  powA(3) = ao_power(i,3)
  A_center(1)=nucl_coord(num_i,1)
  A_center(2)=nucl_coord(num_i,2)
  A_center(3)=nucl_coord(num_i,3)
  do j = i, ao_num
   num_j = ao_nucl(j)
   powB(1) = ao_power(j,1)
   powB(2) = ao_power(j,2)
   powB(3) = ao_power(j,3)
   B_center(1)=nucl_coord(num_j,1)
   B_center(2)=nucl_coord(num_j,2)
   B_center(3)=nucl_coord(num_j,3)
   accu = 0.d0
   do k = 1, ao_prim_num(i)
    do l = 1, ao_prim_num(j)
     call overlap_gaussian_xyz(A_center,B_center,ao_expo(i,k),ao_expo(j,l),powA,powB,overlap_x,overlap_y,overlap_z,norm,nz)
     accu = accu + norm * ao_coef(i,k) * ao_coef(j,l)
    enddo
   enddo
   ao_overlap(i,j) = accu
   ao_overlap(j,i) = accu
  enddo
 enddo

END_PROVIDER


 BEGIN_PROVIDER [ double precision, ao_coef_transp, (ao_prim_num_max_align,ao_num) ]
&BEGIN_PROVIDER [ double precision, ao_expo_transp, (ao_prim_num_max_align,ao_num) ]
 implicit none
 BEGIN_DOC
! Transposed ao_coef and ao_expo
 END_DOC
 integer :: i,j
 do j=1, ao_num
  do i=1, ao_prim_num_max
   ao_coef_transp(i,j) = ao_coef(j,i)
   ao_expo_transp(i,j) = ao_expo(j,i)
  enddo
 enddo


END_PROVIDER


BEGIN_PROVIDER [ integer, ao_prim_num, (ao_num_align) ]
 implicit none

 BEGIN_DOC
! Number of primitives per atomic orbital
 END_DOC

 ao_prim_num = 0
 PROVIDE ezfio_filename
 call ezfio_get_ao_basis_ao_prim_num(ao_prim_num)
 integer :: i
 character*(80) :: message
 do i=1,ao_num
  if (ao_prim_num(i) <= 0) then
   write(message,'(A,I6,A)') 'Number of primitives of contraction ',i,' should be > 0'
   print *,  message
   stop
  endif
 enddo

END_PROVIDER

 BEGIN_PROVIDER [ integer, ao_prim_num_max ]
&BEGIN_PROVIDER [ integer, ao_prim_num_max_align ]
 implicit none
 ao_prim_num_max = 0
 PROVIDE ezfio_filename
 call ezfio_get_ao_basis_ao_prim_num_max(ao_prim_num_max)
 integer :: align_double
 ao_prim_num_max_align = align_double(ao_prim_num_max)
 END_PROVIDER

BEGIN_PROVIDER [ integer, ao_nucl, (ao_num)]
 BEGIN_DOC
! Index of the nuclei on which the ao is centered
 END_DOC
 implicit none
 PROVIDE ezfio_filename
 call ezfio_get_ao_basis_ao_nucl(ao_nucl)
END_PROVIDER
