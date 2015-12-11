#Class fuel_project::devops_tools
#
class fuel_project::devops_tools (
  $lpbugmanage = false,
  $lpupdatebug = false,
) {

  class { '::fuel_project::common' :}

  if($lpbugmanage) {
    class { '::fuel_project::devops_tools::lpbugmanage' :}
  }

  if($lpupdatebug) {
    class { '::fuel_project::devops_tools::lpupdatebug' :}
  }
}
