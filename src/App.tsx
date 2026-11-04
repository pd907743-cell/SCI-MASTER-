
import { useState } from "react";
import {
  Atom,
  FlaskConical,
  Dna,
  BookOpen,
  ClipboardCheck,
  ChartNoAxesCombined,
  Menu,
  ArrowRight,
  GraduationCap,
  Lightbulb,
  Microscope,
  X
} from "lucide-react";

const subjects = [
  {
    name: "Physics",
    description: "Understand how the world works.",
    icon: Atom,
    topics: "Mechanics, Waves, Electricity"
  },
  {
    name: "Chemistry",
    description: "Explore matter and its reactions.",
    icon: FlaskConical,
    topics: "Atomic structure, Bonding, Organic chemistry"
  },
  {
    name: "Biology",
    description: "Discover the science of life.",
    icon: Dna,
    topics: "Cells, Genetics, Ecology"
  }
];

const features = [
  {
    title: "Study Materials",
    description: "Detailed notes, flashcards and mnemonics.",
    icon: BookOpen
  },
  {
    title: "CBT Practice",
    description: "Prepare with examination-style questions.",
    icon: ClipboardCheck
  },
  {
    title: "Virtual Practicals",
    description: "Explore interactive science experiments.",
    icon: Microscope
  },
  {
    title: "Learning Progress",
    description: "Monitor your learning journey.",
    icon: ChartNoAxesCombined
  }
];

export default function App() {
  const [menuOpen, setMenuOpen] = useState(false);
  const [selectedSubject, setSelectedSubject] = useState("");

  return (
    <div className="app">
      <header className="navbar">
        <a className="brand" href="#">
          <span className="brand-icon"><Atom size={25} /></span>
          <span>Sci<span className="blue">Master</span></span>
        </a>

        <button
          className="menu-button"
          onClick={() => setMenuOpen(!menuOpen)}
          aria-label="Toggle navigation"
        >
          {menuOpen ? <X /> : <Menu />}
        </button>

        <nav className={menuOpen ? "nav-links open" : "nav-links"}>
          <a href="#subjects" onClick={() => setMenuOpen(false)}>Subjects</a>
          <a href="#features" onClick={() => setMenuOpen(false)}>Features</a>
          <a href="#about" onClick={() => setMenuOpen(false)}>About</a>
          <a href="#get-started" className="nav-cta">Get Started <ArrowRight size={16}/></a>
        </nav>
      </header>

      <main>
        <section className="hero">
          <div className="hero-content">
            <span className="eyebrow">
              <span className="pulse"></span>
              THE FUTURE OF SCIENCE LEARNING
            </span>

            <h1>
              Think Science.<br />
              <span>Master Knowledge.</span>
            </h1>

            <p>
              Your smarter way to learn Physics, Chemistry and Biology.
              Build understanding, practise confidently and prepare
              for your examinations.
            </p>

            <div className="hero-actions" id="get-started">
              <a href="#subjects" className="primary-button">
                Start Exploring <ArrowRight size={18}/>
              </a>
              <a href="#features" className="secondary-button">
                Explore Features
              </a>
            </div>

            <div className="hero-note">
              <GraduationCap size={19}/>
              <span>Built for secondary school and examination candidates.</span>
            </div>
          </div>

          <div className="hero-visual">
            <div className="orbit orbit-one"></div>
            <div className="orbit orbit-two"></div>
            <div className="science-core">
              <Atom size={100} strokeWidth={1.1}/>
            </div>
            <div className="floating-card card-top">
              <FlaskConical size={21}/>
              <span>Chemistry</span>
            </div>
            <div className="floating-card card-bottom">
              <Dna size={21}/>
              <span>Biology</span>
            </div>
            <div className="floating-label">SCIENCE, REIMAGINED.</div>
          </div>
        </section>

        <section className="section" id="subjects">
          <div className="section-heading">
            <span className="eyebrow">EXPLORE YOUR SUBJECTS</span>
            <h2>Science starts here.</h2>
            <p>Three core subjects. Endless possibilities.</p>
          </div>

          <div className="subject-grid">
            {subjects.map((subject) => {
              const Icon = subject.icon;
              return (
                <button
                  className={
                    selectedSubject === subject.name
                      ? "subject-card selected"
                      : "subject-card"
                  }
                  key={subject.name}
                  onClick={() =>
                    setSelectedSubject(subject.name)
                  }
                >
                  <span className="subject-icon"><Icon size={30}/></span>
                  <h3>{subject.name}</h3>
                  <p>{subject.description}</p>
                  <small>{subject.topics}</small>
                  <span className="card-arrow"><ArrowRight size={19}/></span>
                </button>
              );
            })}
          </div>

          {selectedSubject && (
            <div className="selection-message">
              <span>{selectedSubject} selected.</span>
              <button onClick={() => setSelectedSubject("")}>
                Clear selection
              </button>
            </div>
          )}
        </section>

        <section className="section features-section" id="features">
          <div className="section-heading">
            <span className="eyebrow">LEARN WITHOUT LIMITS</span>
            <h2>More than just textbooks.</h2>
            <p>Everything you need to make science easier to understand.</p>
          </div>

          <div className="feature-grid">
            {features.map((feature) => {
              const Icon = feature.icon;
              return (
                <div className="feature-card" key={feature.title}>
                  <span className="feature-icon"><Icon size={25}/></span>
                  <h3>{feature.title}</h3>
                  <p>{feature.description}</p>
                </div>
              );
            })}
          </div>
        </section>

        <section className="cta-section" id="about">
          <Lightbulb size={32}/>
          <h2>Your potential has no limits.</h2>
          <p>Learn smarter. Practise harder. Understand deeper.</p>
          <a href="#subjects" className="primary-button">
            Explore SciMaster <ArrowRight size={18}/>
          </a>
        </section>
      </main>

      <footer>
        <a className="brand" href="#">
          <Atom size={22}/>
          <span>Sci<span className="blue">Master</span></span>
        </a>
        <p>Science Learning, Reimagined.</p>
        <small>© 2026 SciMaster. All rights reserved.</small>
      </footer>
    </div>
  );
    }
      
