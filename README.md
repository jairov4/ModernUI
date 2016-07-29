ModernUI
========

[![Build status](https://ci.appveyor.com/api/projects/status/xwtq3jpfa1la0fnv?svg=true)](https://ci.appveyor.com/project/jairov4/modernui)
[![DUB version](https://img.shields.io/dub/v/modernui.svg)](https://code.dlang.org/packages/modernui)
[![DUB downloads](https://img.shields.io/dub/dt/modernui.svg)](https://code.dlang.org/packages/modernui)

The most powerful UI engine inspired in XAML and ReactiveUI. 
Is designed to write flexible UI/UX for large and production enterprise-level applications.

Design
======

This library is provided to allow write powerful applications based on native experiences with less hassle tha seen before.
It is inspired in XAML and WPF design to leverage the flexible and full control of each pixel of your applications.

Major aspects:

- Based on two pass layout algorithm.
- Hardware accelerated implementation.
- Reactive by design.
- Easy to use template/style engine.
- Bindings and dependency properties
- Animation included in its design.

How to use
==========

```D
    class MyUserControl : UserControl
    {
    	static this() { registerClass!(typeof(this)); }

        // Define properties that can be data bound and inspected in runtime
        mixin DefineDependencyProperty!(double, "property1");
        mixin DefineDependencyPropertyReadOnly!(double, "propertyro");

        private Button btn;

        this()
        {
            btn = new Button;
            btn.content = "Click me";

            // Click is an observable so we can define its behavior declaratively here
            // take a look of http://reactiveui.net/
            btn.click.then!ClickEvent((ev) 
            {
                btn.content = "You made click";
            });
        }
    }

    auto wnd = new Window;
    auto ctl = new MyUserControl;
    ctl.property1 = 2;
    wnd.content = ctl;
```

Roadmap
=======

Features to add in 0.0.4 will be:

Controls:
- Window: Basic support for layout and live resize. 
- Window: Basic support for mouse and keyboard input. Basic support for background color fill.
- Direct2DRenderContext: API for issue drawing calls against Direct2D
- New primitives: TextBlock, Border, Geometry, SolidColorBrush.

Features to add in 0.0.5 will be:

- Panel: Added panel class. It will allow complex layouts using the new classes: Grid, DockPanel, StackPanel.
- Added controls: Button, TextBox

Features to add in 0.0.6 will be:

- DependencyProperty: Added attached dependency properties.
- ControlTemplate: Basic support for template content
- Style: Basic support for setup properties in cascade.

Features to add in 0.0.7 will be:

- DataTemplate: Basic support for template data bound controls.
- Add new classes: ItemsControl, ItemsPanel, ContentControl, ContentPresenter.

0.0.8 will be a release to fix pending QA issues and tune performance.

Features to add in 0.0.9 will be:

- Parser to load the UI scene graph from XAML or JSON files.

1.0.0 will be our first production release. It will be some limited in features but fully functional.
