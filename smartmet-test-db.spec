%define DIRNAME test-db
%define LIBNAME smartmet-%{DIRNAME}
%define SPECNAME smartmet-%{DIRNAME}
Summary: Smartmet server test database contents
Name: %{SPECNAME}
Version: 20.6.9
Release: 2%{?dist}.fmi
License: MIT
Group: Development/Libraries
URL: https://github.com/fmidev/smartmet-test-db
Source: %{name}.tar.gz
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
BuildArch: noarch
BuildRequires: bzip2
BuildRequires: make
BuildRequires: rpm-build
#TestRequires: make
#TestRequires: postgresql-server
#TestRequires: postgresql-contrib
#TestRequires: postgis < 3
#TestRequires: bzip2
Provides: %{LIBNAME}
Requires: postgresql-contrib
Requires: postgresql-server
Requires: postgis < 3
Requires: bzip2

%description
FMI postgresql database contents and test data installation script.
Database is NOT automatically populated on installing this package.
Use installed script to instead.

%prep
rm -rf $RPM_BUILD_ROOT

%setup -q -n %{SPECNAME}
 
%build
make %{_smp_mflags}

%install
%makeinstall

%clean
rm -rf $RPM_BUILD_ROOT

%files
%defattr(0775,root,root,0775)
%{_datadir}/smartmet/test/db/*

%changelog
* Tue Jun  9 2020 Mika Heiskanen <mika.heiskanen@fmi.fi> - 20.6.9-2.fmi
- Require postgis < 3 from EPEL instead of pgdg95 version

* Tue Jun  9 2020 Mika Heiskanen <mika.heiskanen@fmi.fi> - 20.6.9-1.fmi
- Version update - use EPEL postgresql instead of pgdg95

* Thu May  7 2020 Mika Heiskanen <mika.heiskanen@fmi.fi> - 20.5.7-1.fmi
- Fixed dependencies to be on pgdg95

* Tue Apr 23 2019 Mika Heiskanen <mika.heiskanen@fmi.fi> - 19.4.23-1.fmi
- Database 'iot_obs' for mobile observations added

* Mon Nov 19 2018 Heikki Pernu <heikki.pernu@fmi.fi> - 18.11.19-1.fmi
- Implement PGPORT support on scripts and add drop and stop functionality

* Wed Nov 14 2018 Heikki Pernu <heikki.pernu@fmi.fi> - 18.11.14-1.fmi
- Packaged test DB as an RPM
