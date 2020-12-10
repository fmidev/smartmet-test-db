%define DIRNAME test-db
%define LIBNAME smartmet-%{DIRNAME}
%define SPECNAME smartmet-%{DIRNAME}
Summary: Smartmet server test database contents
Name: %{SPECNAME}
Version: 20.12.9
Release: 1%{?dist}.fmi
License: MIT
Group: Development/Libraries
URL: https://github.com/fmidev/smartmet-test-db
Source: %{name}.tar.gz
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
BuildArch: noarch
%if 0%{rhel} >= 8
BuildRequires: postgresql12-contrib
BuildRequires: postgresql12-server
#TestRequires: postgresql12-contrib
#TestRequires: postgresql12-server
#TestRequires: postgis30_12
Requires: postgresql12-contrib
Requires: postgresql12-server
Requires: postgis30_12
%else
BuildRequires: postgresql-contrib < 9.5
BuildRequires: postgresql-server < 9.5
#TestRequires: postgresql-server < 9.5
#TestRequires: postgresql-contrib < 9.5
#TestRequires: postgis < 3
Requires: postgresql-contrib < 9.5
Requires: postgresql-server < 9.5
Requires: postgis < 3
%endif

BuildRequires: bzip2
BuildRequires: make
BuildRequires: rpm-build
#TestRequires: make
#TestRequires: bzip2
Provides: %{LIBNAME}
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
* Wed Dec  9 2020 Mika Heiskanen <mheiskan@rhel8.dev.fmi.fi> - 20.12.9-1.fmi
- Improved RHEL and PGDG version support

* Wed Dec 02 2020 Andris Pavenis <andris.pavenis@fmi.fi> - 20.12.02-1.fmi
- No more generate prebuilt database as a separate RPM package

* Thu Nov 12 2020 Andris Pavenis <andris.pavenis@fmi.fi> - 20.11.12-1.fmi
- Package built database into a separate RPM package

* Tue Nov  3 2020 Mika Heiskanen <mika.heiskanen@fmi.fi> - 20.11.3-1.fmi
- Updated db-dump.bz2 by dumping the Docker contents

* Tue Oct 27 2020 Mika Heiskanen <mika.heiskanen@fmi.fi> - 20.10.27-1.fmi
- Run test database in port 5444

* Tue Jun  9 2020 Mika Heiskanen <mika.heiskanen@fmi.fi> - 20.6.9-3.fmi
- Require postgresql < 9.5 from EPEL

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
