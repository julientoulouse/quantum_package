program micro_pt2
  implicit none
  BEGIN_DOC
! Helper program to compute the PT2 in distributed mode.
  END_DOC

  read_wf = .False.
  SOFT_TOUCH read_wf
  call provide_everything
  call switch_qp_run_to_master
  call run_wf

end

subroutine provide_everything
  PROVIDE H_apply_buffer_allocated mo_bielec_integrals_in_map psi_det_generators psi_coef_generators psi_det_sorted_bit psi_selectors n_det_generators n_states generators_bitmask zmq_context
end

subroutine run_wf
  use f77_zmq
  implicit none

  integer(ZMQ_PTR), external :: new_zmq_to_qp_run_socket
  integer(ZMQ_PTR) :: zmq_to_qp_run_socket
  double precision :: energy(N_states_diag)

  print *,  'Getting wave function'
  zmq_context = f77_zmq_ctx_new ()

  zmq_to_qp_run_socket = new_zmq_to_qp_run_socket()

  ! TODO : do loop here
  ! TODO : wait_state
  call zmq_get_psi(zmq_to_qp_run_socket,1,energy,size(energy))
  integer :: j,k
  do j=1,N_states_diag
    do k=1,N_det
     CI_eigenvectors(k,j) = psi_coef(k,j)
    enddo
    call get_s2_u0(psi_det,CI_eigenvectors(1,j),N_det,size(CI_eigenvectors,1),CI_eigenvectors_s2(j))
  enddo
  if (.True.) then
    do k=1,size(ci_electronic_energy)
      ci_electronic_energy(k) = energy(k)
    enddo
    SOFT_TOUCH ci_electronic_energy CI_eigenvectors_s2 CI_eigenvectors
    print *,  energy(:)
  endif
  call write_double(6,ci_energy,'Energy')
  zmq_state = 'h_apply_fci_pt2'

  call provide_everything
  integer :: rc, i

  print *,  'Contribution to PT2 running'

  !$OMP PARALLEL PRIVATE(i)
  i = omp_get_thread_num()
  call H_apply_FCI_PT2_slave_tcp(i)
  !$OMP END PARALLEL


end
