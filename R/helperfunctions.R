

check_rmdfiles_exists <- function() {
  require(yaml)
  bookdown_yaml_read <- read_yaml(sort(list.files(pattern = "_bookdown.ya*ml"),TRUE)[1])
  rmd_files <- bookdown_yaml_read$rmd_files
  existing <- file.exists(rmd_files)
  notexisting <- rmd_files[!existing]
  notexisting <- paste(notexisting, collapse = "\n- ")
  if(any(!existing)){
    warning("The following files are listed in your bookdown yaml but do not exist in your project",notexisting)
  } else{
    print("all good, all files specified in bookdown_yaml exist")
  }
}
check_rmdfiles_missing <- function(pattern = ".Rmd") {
  require(yaml)
  require(stringr)
  bookdown_yaml_read <- read_yaml(sort(list.files(pattern = "_bookdown.ya*ml"),TRUE)[1])
  bookdown_yaml_read <- read_yaml(bookdown_yaml)
  rmd_files <- bookdown_yaml_read$rmd_files
  
  rmd_files_all <- list.files(pattern = pattern,full.names = TRUE,recursive = TRUE) %>% str_remove("./")
  
  existing <- rmd_files_all %in% rmd_files
  missing_files <- rmd_files_all[!existing]
  missing_files <- paste(missing_files, collapse = "\n-")
  if(any(!existing)){
    warning("The following files exist in you project but are not listed in your bookdown_yaml\n",missing_files)
  } else{
    print("all good, all files specified in bookdown_yaml exist")
  }
  
}






yaml_to_rmdfiles <- function(rmd_files_yaml){
  require(yaml)
  require(purrr)
  
  rmd_files_yaml %>%
    map(function(part){
      
      if(is.list(part)){
        index_rmd <- part$index
        
        subchapter_rmds <- map(part[["chapters"]], function(chapter){
          
          list(
            file.path(chapter$folder,chapter$index),
            file.path(chapter$folder,chapter$subchapters)
          )
        })
        
        return(list(index_rmd, subchapter_rmds))
      }
      else(
        part
      )
      
    }) 
}


update_bookdownyaml <- function(rmd_files_yaml_name = "_rmd_files.yaml"){
  require(yaml)
  bookdown_yaml_file <- sort(list.files(pattern = "_bookdown.ya*ml"),FALSE)[1]
  bookdown_yaml <- read_yaml(bookdown_yaml_file)
  rmd_files_yaml <- yaml::read_yaml(rmd_files_yaml_name)
  
  
  bookdown_yaml$rmd_files <- unlist(yaml_to_rmdfiles(rmd_files_yaml))
  write_yaml(bookdown_yaml, bookdown_yaml_file)
  warning(bookdown_yaml_file," has been overwritten. Check your git diff!")
}



# This function depends on "rmd_files.yaml" and the way this yaml files captures
# the file structure of this rmd. The idea is, that the function extracts the
# headers > level2 (level 1 headers are hard to distinguish from r-chunk-comments)
# and returns a nested list with links to the chapters

# part: The first hierarchical level of our book ("introduction", geoprocessing tools" etc)
# must be the same name as specified in the yaml file, "_rmd_files.yaml")
# chapter: similar to part, but the name of the chapter as specified in the yaml file
# rmd_files_yaml: the name (including path if neccessary) of the yaml file

hierarchy_to_list <- function(part, chapter,rmd_files_yaml = "_rmd_files.yaml"){
  require(yaml)
  require(purrr)
  require(dplyr)
  require(stringr)
  struc <- read_yaml(rmd_files_yaml)
  
  subchapters <- struc[[part]]$chapters[[chapter]]
  
  file.path(subchapters$folder, subchapters$subchapters) %>%
    map_dfr(function(x){
      
      tibble(mylines = readLines(x)) %>%
        mutate(
          chunkboders = str_starts(mylines, "```"),
          cumsum = cumsum(chunkboders),
          inchunk = cumsum %% 2 == 1 | chunkboders
        ) %>%
        filter(!inchunk) %>%
        filter(str_detect(mylines, "^#{1,}")) %>%
        dplyr::select(mylines)
    }) %>%
    mutate(
      level = str_length(str_match(mylines,"^#{1,}")[,1]),
      level = level-min(level),
      meta = str_match(mylines,"\\{(.+)\\}")[,2],
      mylines = str_remove(mylines, "\\{.+\\}"),
      mylines = str_remove(mylines, "#{1,}"),
      mylines = str_trim(mylines),
      tag = str_match(meta,"#(.+)\\s*")[,2]
    ) %>%
    pmap_chr(function(mylines,level,meta,tag){
      paste0(
        paste(rep(" ",level*2),collapse = ""),
        "- ",
        ifelse(is.na(tag),"",paste0("\\@ref(",tag,") ")),
        "[",mylines,"]",
        ifelse(is.na(tag),"",paste0("(#",tag,")")),
        "\n"
      )
    }) %>%
    cat()
}






preview_chapter_fun <- function(part,chapters, rmd_files_yaml_file = "_rmd_files.yaml", bookdown_yaml_name = "_bookdown.yml") {
  require(yaml)
  require(purrr)
  rmd_files_yaml <- read_yaml(rmd_files_yaml_file)
  
  
  rmd_files_yaml[!names(rmd_files_yaml) %in% c(part,"Meta")] <- NULL
  
  rmd_files_yaml[[part]]$chapters[!names(rmd_files_yaml[[part]]$chapters) %in% chapters] <- NULL
  
  rmds <- unlist(yaml_to_rmdfiles(rmd_files_yaml))
  
  bookdown_yaml <- read_yaml(bookdown_yaml_name)
  
  bookdown_yaml$rmd_files <- rmds
  
  bookdown_yaml_name_temp <- tempfile(pattern = "_bookdown", fileext = ".yml",tmpdir = getwd())
  
  write_yaml(bookdown_yaml,bookdown_yaml_name_temp)
  
  index_location <- bookdown::render_book("index.Rmd",config_file = bookdown_yaml_name_temp)
  
  unlink(bookdown_yaml_name_temp)
  
  rstudioapi::viewer(index_location)
  
}


preview_chapter_app <- function(rmd_files_yaml_file = "_rmd_files.yaml"){
  require(yaml)
  require(purrr)
  require(shiny)
  require(stringr)
  rmd_files_yaml <- read_yaml(rmd_files_yaml_file)
  parts <- imap_chr(rmd_files_yaml, ~.y) 
  chapters <- imap(parts, function(x,y){
    z <- rmd_files_yaml[[x]]
    if(is.list(z)){
      names(rmd_files_yaml[[x]][["chapters"]])
    }
  })
  
  choices <- imap(chapters, function(x,y){
    if(!is.null(x)){
      z <- as.list(paste(y,x,sep = "|"))
      names(z) <- x
      z
    }
    
  })
  
  
  # Define UI for application that draws a histogram
  ui <- fluidPage(
    
    # Application title
    
    # Sidebar with a slider input for number of bins 
    sidebarLayout(
      sidebarPanel(
        textOutput("result")
      ),
      
      # Show a plot of the generated distribution
      mainPanel(
        selectInput("partinput","Select a chapter",choices,multiple = TRUE),
        actionButton("run","build Book")
      )
    )
  )
  
  # Define server logic required to draw a histogram
  server <- function(input, output) {
    
    output$result <- renderText({
      choice_str <- input$partinput
      choice_mat <- str_split_fixed(choice_str,"\\|",2)
      part <- choice_mat[,1]
      chapter <- choice_mat[,2]
      # paste0("You chose part '", part, "' and chapter '",chapter,"'")
      choice_str
    })
    
    observeEvent(input$run, {
      choice_str <- input$partinput
      choice_mat <- str_split_fixed(choice_str,"\\|",2)
      part <- unique(choice_mat[,1])
      
      if(length(part)>1){
        showModal(modalDialog(
          title = "Error",
          "Please select chapters from a single part only",
          easyClose = TRUE
        ))
      } else{
        chapters <- choice_mat[,2]
        showModal(modalDialog(
          title = "Building book now",
          "The book is now going to be built in the console. You can close this dialog now, or it will close automatically after completion.",
          easyClose = TRUE
        ))
        preview_chapter_fun(part = part,chapters = chapters,rmd_files_yaml_file = rmd_files_yaml_file)
        stopApp()
      }
      
    })
  }
  
  # Run the application 
  shinyApp(ui = ui, server = server)
}

