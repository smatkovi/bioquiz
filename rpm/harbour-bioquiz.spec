Name: harbour-bioquiz
Version: 0.2.2
Release: 1
Summary: Biologie-Quiz im Stil von Quizduell
License: Proprietary (private use)
URL: https://github.com/smatkovi/harbour-bioquiz
Source0: %{name}-%{version}.tar.gz

Requires:       sailfishsilica-qt5
Requires:       qt5-qtimageformats-plugin-webp
BuildRequires:  pkgconfig(sailfishapp)
BuildRequires:  pkgconfig(Qt5Core)
BuildRequires:  pkgconfig(Qt5DBus)
BuildRequires:  pkgconfig(Qt5Network)
BuildRequires:  pkgconfig(Qt5Qml)
BuildRequires:  pkgconfig(Qt5Quick)
BuildRequires:  cmake

%description
BioQuiz is a biology quiz in the style of Quizduell with questions from
Austrian school books. Play against the computer or against friends in the
same Wi-Fi network; choose one school level or all of them.

%prep
%setup -q

%build
mkdir -p build
cd build
cmake .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr
make %{?_smp_mflags}

%install
rm -rf %{buildroot}
cd build
make install DESTDIR=%{buildroot}

%files
%defattr(-,root,root,-)
/usr/bin/%{name}
/usr/share/%{name}
/usr/share/applications/%{name}.desktop
/usr/share/icons/hicolor/*/apps/%{name}.png

%changelog
* Wed Oct 14 2026 smatkovi - 0.2.2-1
- Dark text in the (light) Harmattan text fields: name and address were invisible

* Wed Oct 14 2026 smatkovi - 0.2.1-1
- Only the newest edition of each book series: 4141 questions from 12 books

* Wed Oct 14 2026 smatkovi - 0.2.0-1
- Full catalogue: 5601 questions (931 with pictures) from 17 school books
- Bluetooth games (Sailfish OS, Linux, Android), up to 32 players over WLAN
- Wide layout for desktop windows, keys 1-4 and Enter

* Wed Oct 14 2026 smatkovi - 0.1.0-1
- First test build: solo against the computer, Wi-Fi games for 2-8 players,
  school levels, Harmattan look
