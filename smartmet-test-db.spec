%define DIRNAME test-db
%define LIBNAME smartmet-%{DIRNAME}
%define SPECNAME smartmet-%{DIRNAME}
Summary: Smartmet server test database contents
Name: %{SPECNAME}
Version: 24.6.5
Release: 1%{?dist}.fmi
License: MIT
Group: Development/Libraries
URL: https://github.com/fmidev/smartmet-test-db
Source: %{name}.tar.gz
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
BuildArch: noarch
BuildRequires: bzip2
BuildRequires: make
BuildRequires: postgis34_15
BuildRequires: postgresql15-contrib
BuildRequires: postgresql15-server
BuildRequires: rpm-build
Requires: bzip2
Requires: postgis34_15
Requires: postgresql15-contrib
Requires: postgresql15-server
#TestRequires: bzip2
#TestRequires: make
#TestRequires: postgis34_15
#TestRequires: postgresql15-contrib
#TestRequires: postgresql15-server
Provides: %{LIBNAME}

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

%package devel
Summary: FMI SmartMet test database (prebuilt) run as system service
Requires: postgresql15-server
Requires: postgis34_15

%description devel
FMI postgresql database (prebuilt) run as system service

%post devel
systemctl daemon-reload
if [ $1 -eq 1 ]; then
   echo Enabling and starting smartmet-test-db service
   systemctl enable --now smartmet-test-db
else
   echo Starting smartmet-test-db service
   systemctl start smartmet-test-db
fi

%preun devel
if [ $1 -eq 0 ]; then
    echo Stopping and disabling smartmet-test-db service
    systemctl disable --now smartmet-test-db
else
    echo Stopping smartmet-test-db service
    systemctl stop smartmet-test-db
fi

%postun devel
if [ -d %{_localstatedir}/lib/smartmet-test-db ] ; then
    echo "Removing possible remaining previous package files (including generated)"
    rm -rfv %{_localstatedir}/lib/smartmet-test-db
fi

%files devel
%attr(0700,postgres,postgres) %{_localstatedir}/lib/smartmet-test-db
%attr(0644,root,root) %{_prefix}/lib/systemd/system/%{SPECNAME}.service

%changelog
* Wed Jun  5 2024 Andris Pavēnis <andris.pavenis@fmi.fi> 24.6.5-1.fmi
- Update for PostGIS 3.4

* Tue May 14 2024 Andris Pavēnis <andris.pavenis@fmi.fi> 24.5.14-2.fmi
- Fix removing previous package files (including generated) on uninstall or upgrade

* Tue May 14 2024 Andris Pavēnis <andris.pavenis@fmi.fi> 24.5.14-1.fmi
- Repackage

* Fri Jul 21 2023 Andris Pavēnis <andris.pavenis@fmi.fi> 23.7.21-1.fmi
- Move prebuilt test database files to /var/lib/smartmet-test-db

* Thu Jul 13 2023 Andris Pavēnis <andris.pavenis@fmi.fi> 23.7.13-1.fmi
- Update to postgresql-15 and postgis-3.3

* Thu Jun  1 2023 Andris Pavēnis <andris.pavenis@fmi.fi> 23.6.1-1.fmi
- Allow remote connections for installed binary database

* Fri Feb 24 2023 Andris Pavēnis <andris.pavenis@fmi.fi> 23.2.24-2.fmi
- Fix creating SmartMet test database and add new package for prebuilt database

* Thu Apr 14 2022 Pertti Kinnia <pertti.kinnia@fmi.fi> 22.4.14-1.fmi
- avi.dump updated (dumped from docker database, fmidev/smartmet-server-test-db)

* Tue Apr 12 2022 Pertti Kinnia <pertti.kinnia@fmi.fi> 22.4.12-1.fmi
- Fixed create-local-db.sh sql file loading loop to process all given files instead of just the 1'st one. Load spatial_ref_sys.sql too
- Added optional create-local-db.sh parameters; 'pg_restore' to use pg_restore (instead of postgis_restore.pl piped to psql which currently results spatial_ref_sys table to be empty, causing problem with geometry fields) to load dump file(s) and 'collation_C' to use C collation (instead of en_US.UTF-8 which e.g. causes avi test errors due to data ordering changes). Also added possibility to load given dump file(s) only (the rest of command line parameter(s) if any, e.g. only avi.dump is needed by avi tests). The new optional parameters can only be used when db directory (the first parameter which is optional too but can be empty) is given
- Using GMT as the default time zone for avi_user

* Mon Jan 24 2022 Andris Pavēnis <andris.pavenis@fmi.fi> 22.1.24-1.fmi
- Obsolete postgis31_13 to void update conflict

* Fri Jan 21 2022 Andris Pavēnis <andris.pavenis@fmi.fi> 22.1.21-1.fmi
- Repackage due to upgrade of packages from PGDG repo: gdal-3.4, geos-3.10, proj-8.2

* Wed Dec  8 2021 Andris Pavēnis <andris.pavenis@fmi.fi> 21.12.8-1.fmi
- Upgrade to PostgreSQL 13

* Mon Mar  8 2021 Mika Heiskanen <mika.heiskanen@fmi.fi> - 21.3.8-1.fmi
- Set LC_ALL=fi_FI.UTF-8 before calling initdb to get collations working

* Wed Mar  3 2021 Andris Pavēnis <andris.pavenis@fmi.fi> 21.3.3-2.fmi
- Update create-local-db.sh

* Tue Mar  2 2021 Andris Pavēnis <andris.pavenis@fmi.fi> 21.3.2-2.fmi
- Use Unix socket for local test database

* Tue Mar  2 2021 Mika Heiskanen <mika.heiskanen@fmi.fi> - 21.3.2-1.fmi
- Updated collations

* Wed Jan 20 2021 Andris Pavenis <andris.pavenis@fmi.fi> - 21.1.20-1.fmi
- Ensure use of absolute path for $PGDATA in scripts

* Thu Dec 31 2020 Andris Pavenis <andris.pavenis@fmi.fi> - 20.12.31-2.fmi
- Ensure use of currect database version in create-local-db.sh and test-db-ctl.sh

* Thu Dec 31 2020 Andris Pavenis <andris.pavenis@fmi.fi> - 20.12.31-1.fmi
- Fix create-local-db.sh script after adding support for sevaral PosgGis versions

* Tue Dec 29 2020 Mika Heiskanen <mika.heiskanen@fmi.fi> - 20.12.29-1.fmi
- Upgrade to postgis 3.1

* Tue Dec 15 2020 Mika Heiskanen <mika.heiskanen@fmi.fi> - 20.12.15-2.fmi
- Upgrade to pgdg12

* Tue Dec 15 2020 Mika Heiskanen <mika.heiskanen@fmi.fi> - 20.12.15-1.fmi
- Improved postgis_restore script to avoid duplicate functions in the public schema

* Fri Dec 11 2020 Mika Heiskanen <mika.heiskanen@fmi.fi> - 20.12.11-2.fmi
- Upgrade to postgis30_95 on RHEL7

* Fri Dec 11 2020 Mika Heiskanen <mika.heiskanen@fmi.fi> - 20.12.11-1.fmi
- Fixed PGDG paths when installing a local database

* Thu Dec 10 2020 Mika Heiskanen <mheiskan@rhel8.dev.fmi.fi> - 20.12.10-2.fmi
- Updated RHEL8 dependency to postgis31_12

* Thu Dec 10 2020 Mika Heiskanen <mika.heiskanen@fmi.fi> - 20.12.10-1.fmi
- Updated dependencies

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
