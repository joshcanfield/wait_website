module.exports = function(eleventyConfig) {
  // Passthrough static assets and legacy structure as-is
  eleventyConfig.addPassthroughCopy({
    "modules": "modules",
    "misc": "misc",
    "sites": "sites"
  });

  // Watch these for local dev convenience
  eleventyConfig.addWatchTarget("modules");
  eleventyConfig.addWatchTarget("misc");
  eleventyConfig.addWatchTarget("sites");
  eleventyConfig.addWatchTarget("content");

  // Preserve original .html filenames/paths in output (no directory indexes)
  eleventyConfig.addGlobalData("eleventyComputed", {
    permalink: (data) => {
      const input = (data && data.page && data.page.inputPath) || "";
      if (input.endsWith(".html")) {
        return data.page.filePathStem + ".html";
      }
      return data.permalink;
    }
  });

  return {
    dir: {
      input: ".",
      output: "_site",
      includes: "_includes",
      data: "_data"
    },
    templateFormats: ["html", "njk", "md"],
    htmlTemplateEngine: "njk",
    markdownTemplateEngine: "njk",
    passthroughFileCopy: true
  };
};
