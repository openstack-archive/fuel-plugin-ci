# Class: fuel_project::web
#
class fuel_project::web (
  $fuel_landing_page = false,
  $docs_landing_page = false,
) {
  class { '::fuel_project::nginx' :}
  class { '::fuel_project::common' :}

  if ($fuel_landing_page) {
    class { '::landing_page' :}
  }

  if ($docs_landing_page) {
    class { '::landing_page::docs' :}
  }
}
