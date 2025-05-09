defmodule PhoenixStorybook.Rendering.CodeRendererTest do
  use ExUnit.Case, async: true

  alias PhoenixStorybook.{TestStorybook, TreeStorybook}
  alias PhoenixStorybook.Rendering.{CodeRenderer, RenderingContext}
  import Phoenix.LiveViewTest, only: [rendered_to_string: 1]

  setup_all do
    [
      component: TreeStorybook.load_story("/component") |> elem(1),
      live_component: TreeStorybook.load_story("/live_component") |> elem(1),
      afolder_component: TreeStorybook.load_story("/a_folder/component") |> elem(1),
      afolder_live_component: TreeStorybook.load_story("/a_folder/live_component") |> elem(1),
      template_component: TreeStorybook.load_story("/templates/template_component") |> elem(1),
      all_types_component: TreeStorybook.load_story("/b_folder/all_types_component") |> elem(1),
      template_component: TreeStorybook.load_story("/templates/template_component") |> elem(1)
    ]
  end

  describe "render_variation_code/2" do
    test "it should return HEEX for each component/variation couple", %{
      component: component,
      live_component: live_component
    } do
      code = render_variation_code(component, :hello)
      assert code =~ ~s|<.component id="component-single-hello" label="hello"/>|

      code = render_variation_code(component, :world)
      assert code =~ ~s|<.component id="component-single-world" index={37} label="world"/>|

      code = render_variation_code(component, :lengthy)

      assert code =~
               String.trim("""
               <.component
                 id="component-single-lengthy"
                 index={37}
                 label="Omnis rerum facere aspernatur ipsum velit et illum in earum quia modi molestias qui sunt."
               />
               """)

      code = render_variation_code(live_component, :hello)
      assert code =~ ~s|<.live_component module={LiveComponent} label="hello"/>|

      code = render_variation_code(live_component, :world)

      assert code =~
               String.trim("""
               <.live_component module={LiveComponent} label="world">
                 <span>inner block</span>
               </.live_component>
               """)

      code = render_variation_code(live_component, :lengthy)

      assert code =~
               String.trim("""
               <.live_component
                 module={LiveComponent}
                 label="Omnis rerum facere aspernatur ipsum velit et illum in earum quia modi molestias qui sunt."
               />
               """)
    end

    test "it also works for a variation group", %{
      afolder_component: component,
      afolder_live_component: live_component
    } do
      code = render_variation_code(component, :group)

      assert code =~
               String.trim("""
               <.component label="hello"/>
               <.component index={37} label="world"/>
               """)

      code = render_variation_code(live_component, :group)

      assert code =~
               String.trim("""
               <.live_component module={LiveComponent} label="hello">
                 <span>inner block</span>
               </.live_component>
               <.live_component module={LiveComponent} label="world"/>
               """)
    end

    test "it is working with a variation without any attributes", %{afolder_component: component} do
      code = render_variation_code(component, :no_attributes)
      assert code =~ ~s|<.component />|
    end

    test "it is working with an inner_block requiring a let attribute" do
      {:ok, component} = TreeStorybook.load_story("/let/let_component")
      code = render_variation_code(component, :default)

      assert code =~
               String.trim("""
               <.let_component stories={["foo", "bar", "qix"]}>
                 <:my_slot :let={entry}>**<%= entry %>**</:my_slot>
               </.let_component>
               """)
    end

    test "it is working with an inner_block requiring a let attribute, in a live component" do
      {:ok, component} = TreeStorybook.load_story("/let/let_live_component")
      code = render_variation_code(component, :default)

      assert code =~
               String.trim("""
               <.live_component module={LetLiveComponent} :let={entry} stories={["foo", "bar", "qix"]}>
                 **<%= entry %>**
               </.live_component>
               """)
    end

    test "it is working with a template component", %{template_component: component} do
      code = render_variation_code(component, :hello)

      assert code =~
               String.trim("""
               <div id="template-component-single-hello" class="template-div">
                 <button id="set-foo-template-component-single-hello" phx-click={JS.push("psb-assign", value: %{label: "foo"})}>Set label to foo</button>
                 <button id="set-bar-template-component-single-hello" phx-click={JS.push("psb-assign", value: %{label: "bar"})}>Set label to bar</button>
                 <button id="toggle-status-template-component-single-hello" phx-click={JS.push("psb-toggle", value: %{attr: :status})}>Toggle status</button>
                 <button id="set-status-true-template-component-single-hello" phx-click={JS.push("psb-assign", value: %{status: true})}>Set status to true</button>
                 <button id="set-status-false-template-component-single-hello" phx-click={JS.push("psb-assign", value: %{status: false})}>Set status to false</button>
                 <.template_component label="hello"/>
               </div>
               """)
    end

    test "it is working with a group template", %{template_component: component} do
      code = render_variation_code(component, :group_template)

      assert code =~
               String.trim("""
               <div class="group-template">
                 <.template_component label="one"/>
               </div>

               <div class="group-template">
                 <.template_component label="two"/>
               </div>
               """)
    end

    test "it is working with a single group template", %{template_component: component} do
      code = render_variation_code(component, :group_template_single)

      assert code =~
               String.trim("""
               <div class="group-template">
                 <.template_component label="one"/>
                 <.template_component label="two"/>
               </div>
               """)
    end

    test "it is working with a hidden group template", %{template_component: component} do
      code = render_variation_code(component, :group_template_hidden)

      assert code =~
               String.trim("""
               <.template_component label="one"/>
               <.template_component label="two"/>
               """)
    end

    test "it is working with a component and a disabled template", %{
      template_component: component
    } do
      code = render_variation_code(component, :no_template)

      assert code =~ ~s|<.template_component label="variation without template"/>|
      refute code =~ ~s|template-div|
    end

    test "it is working with a component and a hidden template", %{
      template_component: component
    } do
      code = render_variation_code(component, :hidden_template)

      assert code =~ ~s|<.template_component label="variation hidden template"/>|
      refute code =~ ~s|variation-template|
    end

    test "it prints aliases struct names" do
      {:ok, component} = TreeStorybook.load_story("/b_folder/all_types_component")
      code = render_variation_code(component, :with_struct)

      assert code =~
               String.trim("""
               <.all_types_component label="foo" struct={%Struct{name: "bar"}}>
                 <p>inner block</p>
               </.all_types_component>
               """)
    end

    test "its renders properly global attributes", %{all_types_component: component} do
      code = render_variation_code(component, :default)

      assert code =~
               String.trim("""
               <.all_types_component label="default label" foo="bar" data-bar={42}>
                 <p>will be displayed in inner block</p>
                 <:slot_thing>slot 1</:slot_thing>
                 <:slot_thing>slot 2</:slot_thing>
                 <:other_slot>not displayed</:other_slot>
               </.all_types_component>
               """)
    end

    test "it renders component id only if it has a declared :id attribute" do
      {:ok, component} = TreeStorybook.load_story("/b_folder/with_id_component")
      code = render_variation_code(component, :default)
      assert code =~ ~s|<.component id="with-id-component-single-default"/>|
    end

    test "renders a variation with an evaluated attribute", %{all_types_component: component} do
      code = render_variation_code(component, :with_eval)
      assert code =~ ~r|<.all_types_component.*index_i={10 \+ 15}.*>|
      assert code =~ ~r|<.all_types_component.*label="with eval".*>|
    end
  end

  describe "render_component_source/2" do
    test "it renders a component source", %{component: component} do
      source = CodeRenderer.render_component_source(component) |> rendered_to_string()
      assert source =~ ~r/<pre.*psb highlight.*\/pre>/s
    end

    test "it renders a live component source", %{live_component: component} do
      source = CodeRenderer.render_component_source(component) |> rendered_to_string()
      assert source =~ ~r/<pre.*psb highlight.*\/pre>/s
    end
  end

  describe "render_code_block/3" do
    test "it renders Elixir code" do
      code = """
      def hello_world do
        IO.puts(\"Hello, world!\")
      end
      """

      source = CodeRenderer.render_code_block(code, :elixir) |> rendered_to_string()
      assert source =~ ~r/<pre.*psb highlight.*\/pre>/s
      assert source =~ ~s[<span class="kd">def</span>]
    end

    test "it renders HEEx code" do
      code = """
      <.button phx-click="go">Send!</.button>
      """

      source = CodeRenderer.render_code_block(code, :heex) |> rendered_to_string()
      assert source =~ ~r/<pre.*psb highlight.*\/pre>/s
      assert source =~ ~s[<span class="nf">.button</span>]
    end

    test "it does not highlight syntax when `format: false` is given" do
      code = """
      <.button phx-click="go">Send!</.button>
      """

      source = CodeRenderer.render_code_block(code, :heex, format: false) |> rendered_to_string()
      assert source =~ ~r/<pre.*psb highlight.*\/pre>/s
      assert source =~ ~s[<.button phx-click="go">Send!</.button>]
    end

    test "it does not trim whitespace when `trim: false` is given" do
      code = """
        <.button phx-click="go">Send!</.button>
      """

      source =
        CodeRenderer.render_code_block(code, :heex, trim: false, format: false)
        |> rendered_to_string()

      assert source =~ ~r/<pre.*psb highlight.*\/pre>/s
      assert source =~ ~s[  <.button phx-click="go">Send!</.button>]
    end
  end

  describe "render booleans with their shorthand notation" do
    test "when true, the attribute is rendered, shorthand", %{all_types_component: component} do
      code = render_variation_code(component, :toggle_true)
      assert code =~ "toggle"
      refute code =~ "toggle={true}"
    end

    test "when false, the attribute is not rendered", %{all_types_component: component} do
      code = render_variation_code(component, :default)
      refute code =~ "toggle"
    end
  end

  describe "theme attribute may be stripped from the code" do
    test "with default theme strategy, not stripped", %{component: component} do
      code = render_variation_code(component, :themed)
      assert code =~ "theme={:blue}"
    end

    test "with assign theme strategy, the given assign is stripped from code", %{
      component: component
    } do
      code = render_variation_code(TestStorybook, component, :themed)
      refute code =~ "theme={:blue}"
    end
  end

  defp render_variation_code(backend_module \\ TreeStorybook, story, variation_id) do
    variation = Enum.find(story.variations(), &(&1.id == variation_id))

    backend_module
    |> RenderingContext.build(story, variation, %{}, format: false)
    |> CodeRenderer.render()
    |> rendered_to_string()
  end
end
